------------------------------------------------------------------------------
--                                                                          --
--                               GNATcoverage                               --
--                                                                          --
--                     Copyright (C) 2012-2021, AdaCore                     --
--                                                                          --
-- GNATcoverage is free software; you can redistribute it and/or modify it  --
-- under terms of the GNU General Public License as published by the  Free  --
-- Software  Foundation;  either version 3,  or (at your option) any later  --
-- version. This software is distributed in the hope that it will be useful --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Containers.Vectors;
with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Directories;         use Ada.Directories;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Tags;
with Ada.Text_IO;             use Ada.Text_IO;

with GNAT.OS_Lib;

with GNATCOLL.Traces;
with GNATCOLL.Projects; use GNATCOLL.Projects;
with GNATCOLL.Projects.Aux;
with GNATCOLL.VFS;      use GNATCOLL.VFS;

with Inputs;   use Inputs;
with Outputs;  use Outputs;
with Strings;
with Switches; use Switches;

package body Project is

   Coverage_Package      : aliased String := "coverage";
   Coverage_Package_List : aliased String_List :=
                             (1 => Coverage_Package'Access);

   type Attribute is
     (Units,
      Excluded_Units,
      Routines,
      Excluded_Routines,
      Ignored_Source_Files,
      Switches,

      Units_List,
      Excluded_Units_List,
      Routines_List,
      Excluded_Routines_List,
      Ignored_Source_Files_List);

   subtype List_Attribute is
     Attribute range Units .. Switches;
   subtype String_Attribute is
     Attribute range Units_List .. Ignored_Source_Files_List;

   function "+" (A : Attribute) return String;
   function "+" (A : String_Attribute) return Attribute_Pkg_String;
   function "+" (A : List_Attribute) return Attribute_Pkg_List;
   --  Build identifiers for attributes in package Coverage

   procedure Iterate_Source_Files
     (Root_Project     : Project_Type;
      Process          : access procedure
        (Info : File_Info; Unit_Name : String);
      Recursive        : Boolean;
      Include_Subunits : Boolean := False);
   --  Call Process on all source files in Root_Project (recursively
   --  considering source files of sub-projects if Recursive is true).
   --
   --  This passes the name of the unit as Unit_Name for languages featuring
   --  this notion (Ada) and the base file name otherwise (i.e. for C sources).
   --  If Include_Subunits is false (default), then skip all files that
   --  implement subunits.

   Env : Project_Environment_Access;
   --  Environment in which we load the project tree

   Prj_Tree : Project_Tree_Access;
   --  Loaded project tree

   Obj_Subdir : Unbounded_String;
   --  Hold the object subdirectory to use (if any) for all loaded projects.
   --  Should be processed each time we load a project tree.

   Externally_Built_Projects_Processing_Enabled : Boolean := False;
   --  Whether to include projects marked as externally built to processings

   type Project_Info is record
      Project : Project_Type;
      --  The project this info relates to

      Has_Units_Of_Interest : Boolean;
      --  Whether this project contributed to the selection of units of
      --  interest. They do contribute either:
      --
      --    * having unit selection attributes or containing units of interest
      --      (if no --units argument is passed)
      --
      --    * having at least one unit of interest (as soon as one --units
      --      argument is passed).
   end record;

   package Project_Sets is new Ada.Containers.Indefinite_Ordered_Sets
     (Element_type => String);
   package Project_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type     => String,
      Element_Type => Project_Info);

   Requested_Projects : Project_Sets.Set;
   --  Set of all projects passed to the Add_Project procedure

   Prj_Map : Project_Maps.Map;
   --  Map of all projects for which coverage analysis is desired. Populated in
   --  Build_Prj_Map, called from Load_Root_Project.

   package Unit_Name_Sets is new Ada.Containers.Indefinite_Ordered_Sets
     (Element_Type => String);

   type Unit_Info is record
      Original_Name : Unbounded_String;
      --  Units are referenced in unit maps under their lowercased name.
      --  Here we record the name with original casing (from the project or
      --  the command line).

      Present_In_Projects : Boolean;
      --  Whether we found at least one source file in the projects of interest
      --  that matches this unit.

      Is_Subunit : Boolean;
      --  Whether this unit is actually a subunit. We consider that subunits
      --  are not units of their own (in particular they don't have their own
      --  LI file), but we still allow them to appear in unit lists.

      LI_Seen : Boolean;
      --  Set true if the LI file for this unit has been seen

      Warned_About_Missing_Info : Boolean;
      --  Whether Warn_Missing_Info was called for this unit
   end record;

   package Unit_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type     => String,
      Element_Type => Unit_Info);

   procedure Add_Unit
     (Units         : in out Unit_Maps.Map;
      Cur           : out Unit_Maps.Cursor;
      Original_Name : String);
   --  Add an entry to Units. See Unit_Info's members for the semantics of
   --  arguments.

   procedure Warn_Missing_Info (What_Info : String; Unit : in out Unit_Info);
   --  If we haven't already, warn that we miss information (ALI or SID) about
   --  Unit.

   Unit_Map : Unit_Maps.Map;
   --  Map lower-case unit names to Unit_Info records for all units of interest

   Are_LIs_Enumerated : Boolean := False;
   --  Return whether Enumerate_LIs was called

   Are_SIDs_Enumerated : Boolean := False;
   --  Return whether Enumerate_SIDs was called

   procedure Initialize
     (Target, Runtime, CGPR_File : GNAT.Strings.String_Access)
      with Pre => (Target = null and then Runtime = null)
                  or else CGPR_File = null;
   --  Initialize project environment. Formals have the same semantics as in
   --  Load_Root_Project.

   procedure Build_Prj_Map with Pre => Is_Project_Loaded;
   --  Add entries in Prj_Map for all relevant projects

   procedure Build_Unit_Map (Override_Units : Inputs.Inputs_Type);
   --  Add entries in Unit_Map for all units of interest

   procedure List_From_Project
     (Prj            : Project_Type;
      List_Attr      : List_Attribute;
      List_File_Attr : String_Attribute;
      Process_Item   : access procedure (Attr, Item : String);
      Defined        : out Boolean);
   --  If List_Attr, an attribute that can contain a list of strings, is
   --  defined in Prj, call Process_Item on each of the strings and set
   --  Defined. If List_File_Attr, an attribute that can contain a file name,
   --  is defined in Prj, read each line from the file and call Process_Item on
   --  each line, then set Defined. Just reset Defined if no attribute is
   --  defined.

   procedure Units_From_Project
     (Prj            : Project_Type;
      List_Attr      : List_Attribute;
      List_File_Attr : String_Attribute;
      Units          : out Unit_Maps.Map;
      Defined        : out Boolean);
   --  Build a map of units from project attributes.
   --
   --  This considers that List_Attr is an attribute that can contain a list of
   --  unit names and that List_File_Attr is an attribute that can contain a
   --  file name for a text file, and that this file contains one unit name per
   --  line.
   --
   --  If Prj contains at least one of these attributes, set Defined to True
   --  and fill Units with one entry per unit. Set Defined to False otherwise.

   function Enumerate_Mains
     (Root_Project : Project_Type;
      Language     : String := "") return Main_Source_File_Array;
   --  Helper for Get_Single_Main_Executable. Return the list of all main
   --  source files recursively found in the Root_Project.
   --
   --  Note that this also returns source files for mains that are not units of
   --  interest.
   --
   --  If Language is not an empty string, only return source files whose
   --  language matches it.

   ---------
   -- "+" --
   ---------

   function "+" (A : Attribute) return String is
   begin
      return Coverage_Package & "." & To_Lower (A'Image);
   end "+";

   function "+" (A : String_Attribute) return Attribute_Pkg_String is
   begin
      return Build (Coverage_Package, A'Img);
   end "+";

   function "+" (A : List_Attribute) return Attribute_Pkg_List is
   begin
      return Build (Coverage_Package, A'Img);
   end "+";

   --------------
   -- Add_Unit --
   --------------

   procedure Add_Unit
     (Units         : in out Unit_Maps.Map;
      Cur           : out Unit_Maps.Cursor;
      Original_Name : String)
   is
      Ignored_Inserted : Boolean;
      Orig_Name        : constant Unbounded_String :=
         To_Unbounded_String (Original_Name);
   begin
      Units.Insert
        (Key      => To_Lower (Original_Name),
         New_Item => (Original_Name             => Orig_Name,
                      Present_In_Projects       => False,
                      Is_Subunit                => False,
                      LI_Seen                   => False,
                      Warned_About_Missing_Info => False),
         Position => Cur,
         Inserted => Ignored_Inserted);
   end Add_Unit;

   -----------------------
   -- Warn_Missing_Info --
   -----------------------

   procedure Warn_Missing_Info (What_Info : String; Unit : in out Unit_Info) is
   begin
      if Unit.Warned_About_Missing_Info then
         return;
      end if;

      Warn ("no " & What_Info & " file found for unit "
            & To_String (Unit.Original_Name));
      Unit.Warned_About_Missing_Info := True;
   end Warn_Missing_Info;

   ----------------------
   -- Iterate_Projects --
   ----------------------

   procedure Iterate_Projects
     (Root_Project : Project_Type;
      Process      : access procedure (Prj : Project_Type);
      Recursive    : Boolean;
      Extended     : Boolean := False)
   is
      Iter             : Project_Iterator := Start
        (Root_Project     => Root_Project,
         Recursive        => Recursive,
         Include_Extended => False);
      Visited_Projects : Project_Sets.Set;
      Project          : Project_Type;

   begin
      loop
         Project := Current (Iter);
         exit when Project = No_Project;

         --  Unless specifically asked to go through extended projects, go to
         --  the ultimate extending project, which might override the Coverage
         --  package.

         if not Extended then
            Project := Extending_Project (Project, Recurse => True);
         end if;

         declare
            Name : constant String := Project.Name;
         begin
            --  Skip externally built projects unless they are explicitly
            --  requested.

            if (Externally_Built_Projects_Processing_Enabled
                or else not Project.Externally_Built)
               and then not Visited_Projects.Contains (Name)
            then
               Process (Project);
               Visited_Projects.Insert (Name);
            end if;
         end;

         Next (Iter);
      end loop;
   end Iterate_Projects;

   --------------------------
   -- Iterate_Source_Files --
   --------------------------

   procedure Iterate_Source_Files
     (Root_Project     : Project_Type;
      Process          : access procedure
        (Info : File_Info; Unit_Name : String);
      Recursive        : Boolean;
      Include_Subunits : Boolean := False)
   is
      --  If Root_Project is extending some project P, consider for coverage
      --  purposes that source files in P also belong to Root_Project. For
      --  instance, if Root_Project extends P only to replace some of P's units
      --  with stubs, users most likely want to compute the coverage of other
      --  units in P.
      --
      --  When Recursive is true, there is nothing specific to do, as
      --  Source_Files will go through extended projects. However, when
      --  recursive is False, use Extended_Projects_Source_Files to go through
      --  them.

      Source_Files : File_Array_Access :=
        (if Recursive
         then Root_Project.Source_Files (Recursive => True)
         else Root_Project.Extended_Projects_Source_Files);
   begin
      for F of Source_Files.all loop
         declare
            use type Ada.Tags.Tag;

            Infos : constant File_Info_Set := Prj_Tree.Info_Set (F);
         begin
            for Abstract_Info of Infos loop

               --  ??? It seems that GNATCOLL.Projects.Info_Set always put
               --  File_Info records in File_Info_Sets.Set containers, so it's
               --  not clear why File_Info_Sets.Set contains
               --  File_Info_Abstract'Class objects instead. Anyway, put
               --  defensive code here to avoid constraint errors if that is
               --  not true one day.

               if Abstract_Info'Tag = File_Info'Tag then
                  declare
                     Info : constant File_Info := File_Info (Abstract_Info);
                  begin
                     --  Register only units in supported languages (Ada and
                     --  C), and don't consider subunits as independent units.
                     if To_Lower (Info.Language) in "ada" | "c"
                       and then (Include_Subunits
                                 or else Info.Unit_Part /= Unit_Separate)
                     then
                        Process.all
                          (Info      => Info,
                           Unit_Name => (if Info.Unit_Name = ""
                                         then +F.Base_Name
                                         else Info.Unit_Name));
                     end if;
                  end;
               end if;
            end loop;
         end;
      end loop;
      Unchecked_Free (Source_Files);
   end Iterate_Source_Files;

   -----------------
   -- Add_Project --
   -----------------

   procedure Add_Project (Prj_Name : String) is
   begin
      Requested_Projects.Include (Prj_Name);
   end Add_Project;

   ---------------------------------
   -- Enumerate_Units_Of_Interest --
   ---------------------------------

   procedure Enumerate_Units_Of_Interest
     (Callback : access procedure (Name : String; Is_Subunit : Boolean))
   is
      use Unit_Maps;
   begin
      for Cur in Unit_Map.Iterate loop
         declare
            Info : Unit_Info renames Reference (Unit_Map, Cur);
         begin
            Callback (Key (Cur), Info.Is_Subunit);
         end;
      end loop;
   end Enumerate_Units_Of_Interest;

   -------------------
   -- Enumerate_LIs --
   -------------------

   procedure Enumerate_LIs (LI_Cb : access procedure (LI_Name : String)) is
      Lib_Info : Library_Info_List;
   begin
      --  Go through all library files in all projects of interest

      for Prj_Info of Prj_Map loop
         Prj_Info.Project.Library_Files
           (List => Lib_Info, ALI_Ext => "^.*\.[ag]li$");
         for LI of Lib_Info loop

            --  If the unit for this library file is in Unit_Map, this is a
            --  unit of interest, so use it.

            declare
               use Unit_Maps;

               LI_Source_Unit : constant String := LI.Source.Unit_Name;
               LI_Source_File : constant String := +LI.Source.File.Base_Name;

               U  : constant String :=
                      (if LI_Source_Unit'Length > 0
                       then LI_Source_Unit
                       else LI_Source_File);
               --  For unit-based languages (Ada), retrieve unit name from LI
               --  file. For file-based languages (C), fall back to translation
               --  unit source file name instead.

               Cur : constant Cursor := Unit_Map.Find (U);
            begin
               if Has_Element (Cur) then
                  LI_Cb.all (+LI.Library_File.Full_Name);
                  Unit_Map.Reference (Cur).LI_Seen := True;
               end if;
            end;
         end loop;
         Lib_Info.Clear;
      end loop;

      Are_LIs_Enumerated := True;
   end Enumerate_LIs;

   --------------------
   -- LIs_Enumerated --
   --------------------

   function LIs_Enumerated return Boolean is
   begin
      return Are_LIs_Enumerated;
   end LIs_Enumerated;

   -----------------------------
   -- Report_Units_Without_LI --
   -----------------------------

   procedure Report_Units_Without_LI is
   begin
      for UI of Unit_Map loop
         if not UI.Is_Subunit and then not UI.LI_Seen then
            Warn_Missing_Info ("ALI", UI);
         end if;
      end loop;
   end Report_Units_Without_LI;

   --------------------
   -- Enumerate_SIDs --
   --------------------

   procedure Enumerate_SIDs (Callback : access procedure (SID_Name : String))
   is
      Lib_Info : Library_Info_List;
   begin
      --  Go through all SID files in all projects of interest

      for Prj_Info of Prj_Map loop
         Prj_Info.Project.Library_Files
           (List => Lib_Info, ALI_Ext => "^.*\.sid$");
         for LI of Lib_Info loop

            --  If the unit for this SID file is in Unit_Map, this is a unit of
            --  interest, so use it.

            declare
               use Unit_Maps;

               Cur : constant Cursor := Unit_Map.Find (LI.Source.Unit_Name);
            begin
               if Has_Element (Cur) then
                  Callback.all (+LI.Library_File.Full_Name);
                  Unit_Map.Reference (Cur).LI_Seen := True;
               end if;
            end;
         end loop;
         Lib_Info.Clear;
      end loop;

      --  Now warn about units of interest that have no SID

      for UI of Unit_Map loop
         if not UI.Is_Subunit and then not UI.LI_Seen then
            Warn_Missing_Info ("SID", UI);
         end if;
      end loop;

      Are_SIDs_Enumerated := True;
   end Enumerate_SIDs;

   ---------------------
   -- SIDs_Enumerated --
   ---------------------

   function SIDs_Enumerated return Boolean is
   begin
      return Are_SIDs_Enumerated;
   end SIDs_Enumerated;

   -----------------------
   -- Enumerate_Sources --
   -----------------------

   procedure Enumerate_Sources
     (Callback         : access procedure
        (Project : GNATCOLL.Projects.Project_Type;
         File    : GNATCOLL.Projects.File_Info);
      Language         : String;
      Include_Subunits : Boolean := False)
   is
      procedure Process_Source_File (Info : File_Info; Unit_Name : String);
      --  Callback for Iterate_Source_File. If Unit_Name is a unit of interest,
      --  call "Callback" on this file.

      -------------------------
      -- Process_Source_File --
      -------------------------

      procedure Process_Source_File (Info : File_Info; Unit_Name : String) is
      begin
         if To_Lower (Info.Language) = To_Lower (Language)
           and then
             (Include_Subunits
              or else Unit_Map.Contains (To_Lower (Unit_Name)))
         then
            Callback (Info.Project, Info);
         end if;
      end Process_Source_File;

   begin
      --  Go through all sources files in all projects of interest

      for Prj_Info of Prj_Map loop
         Iterate_Source_Files
           (Prj_Info.Project,
            Process_Source_File'Access,
            Recursive        => False,
            Include_Subunits => Include_Subunits);
      end loop;
   end Enumerate_Sources;

   ----------------------
   -- Find_Source_File --
   ----------------------

   function Find_Source_File (Simple_Name : String)
                              return GNAT.Strings.String_Access
   is
   begin
      if Prj_Tree = null then
         return null;
      end if;

      declare
         Result : constant Virtual_File := GNATCOLL.Projects.Create
           (Self            => Prj_Tree.all,
            Name            => +Simple_Name,
            Use_Object_Path => False);
      begin
         if Result = No_File then
            return null;
         else
            return new String'(+Full_Name (Result));
         end if;
      end;
   end Find_Source_File;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Target, Runtime, CGPR_File : GNAT.Strings.String_Access)
   is
      use Key_Element_Maps;
   begin
      Initialize (Env);

      --  If no configuration project file is passed, automatically generate
      --  one so that we extract the same information from user project files
      --  as GPRbuild does, like precise executable names.

      if CGPR_File = null then
         Env.Set_Automatic_Config_File;
      else
         Env.Set_Config_File (Create (+CGPR_File.all));
      end if;

      --  Prepare for C units handling (by default, only Ada units are handled
      --  in projects).

      Register_Default_Language_Extension
        (Self                => Env.all,
         Language_Name       => "C",
         Default_Spec_Suffix => ".h",
         Default_Body_Suffix => ".c",
         Obj_Suffix          => ".o");

      --  Register attributes of package Coverage

      for A in Attribute'Range loop
         declare
            Err : constant String :=
                    Register_New_Attribute
                      (Name    => A'Img,
                       Pkg     => Coverage_Package,
                       Is_List => A in List_Attribute,
                       Indexed => (A = Switches));
         begin
            if Err /= "" then
               Fatal_Error (Err);
            end if;
         end;
      end loop;

      --  If provided, override the project target

      if Target /= null or else Runtime /= null then
         Env.Set_Target_And_Runtime
           (Target  => (if Target = null then "" else Target.all),
            Runtime => (if Runtime = null then "" else Runtime.all));
      end if;

      --  Set project search path for target

      declare
         Gnatls_Version : GNAT.Strings.String_Access;
      begin
         Env.Set_Path_From_Gnatls
           (Gnatls       => (if Target = null then "" else Target.all & '-')
                              & "gnatls",
            GNAT_Version => Gnatls_Version,
            Errors       => null);
         if Verbose and then Gnatls_Version /= null then
            Put_Line
              ("default paths set from GNATLS " & Gnatls_Version.all);
            Free (Gnatls_Version);
         end if;
      end;

      --  Set scenario variables

      for Scv_C in S_Variables.Iterate loop
         Change_Environment (Env.all, Key (Scv_C), Element (Scv_C));
      end loop;

      --  Make sure GPR_TOOL is initalized. There are several ways to
      --  initialize it: by decreasing order of precedence:
      --
      --    * explicitly set through a -X option;
      --    * set through an environment variable;
      --    * implicitly initialized by GNATcoverage.

      if S_Variables.Contains ("GPR_TOOL") then
         null;

      else
         declare
            GPR_Tool_Env_Var : GNAT.Strings.String_Access :=
               GNAT.OS_Lib.Getenv ("GPR_TOOL");
            GPR_Tool_Value   : constant String :=
              (if GPR_Tool_Env_Var.all = ""
               then "gnatcoverage"
               else GPR_Tool_Env_Var.all);
         begin
            Change_Environment (Env.all, "GPR_TOOL", GPR_Tool_Value);
            Free (GPR_Tool_Env_Var);
         end;
      end if;
   end Initialize;

   -------------------
   -- Build_Prj_Map --
   -------------------

   procedure Build_Prj_Map is

      function Lookup_Project (Prj_Name : String) return Project_Type;
      --  Look for the project in Prj_Tree whose name matches Prj_Name and
      --  return it. Emit a fatal error if there is no such project.

      procedure Process_Project (Project : Project_Type);
      --  Callback for Iterate_Projects: add an entry in Prj_Map for Project

      --------------------
      -- Lookup_Project --
      --------------------

      function Lookup_Project (Prj_Name : String) return Project_Type is
         Prj_Name_FS : constant GNATCOLL.VFS.Filesystem_String :=
           +Simple_Name (Prj_Name);
         Last        : Integer;
      begin
         --  Strip optional Project_File_Extension

         if Prj_Name_FS'Length >= Project_File_Extension'Length
              and then
            Prj_Name_FS (Prj_Name_FS'Last - Project_File_Extension'Length + 1
                         .. Prj_Name_FS'Last) = Project_File_Extension
         then
            Last := Prj_Name_FS'Last - Project_File_Extension'Length;
         else
            Last := Prj_Name_FS'Last;
         end if;

         --  Look up project from project tree

         return Result : constant Project_Type := Prj_Tree.Project_From_Name
           (+Prj_Name_FS (Prj_Name_FS'First .. Last))
         do
            if Result = No_Project then
               Fatal_Error ("project " & Prj_Name & " not found");
            end if;
         end return;
      end Lookup_Project;

      ---------------------
      -- Process_Project --
      ---------------------

      procedure Process_Project (Project : Project_Type) is
         use Project_Maps;

         Success : Boolean;
         Cur     : Cursor;
      begin
         --  In recursive mode or when users pass the same project several
         --  times to --projects, Process_Project can be called on the same
         --  project multiple times. In theory, all projects are supposed to
         --  have a unique name, though: check this.

         Prj_Map.Insert
           (Project.Name,
            (Project => Project, others => False),
            Cur,
            Success);
         if not Success and then Prj_Map.Reference (Cur).Project /= Project
         then
            raise Program_Error with
               "homonym projects detected: " & Project.Name;
         end if;
      end Process_Project;

   --  Start of processing for Build_Prj_Map

   begin
      --  If no project was specified, consider the root one. If this root
      --  project has an Origin_Project attribute, actually use this project
      --  instead.

      if Requested_Projects.Is_Empty then
         declare
            Origin_Prj : constant String :=
               Prj_Tree.Root_Project.Attribute_Value
                 (Origin_Project_Attribute);
            Prj_Name   : constant String :=
              (if Origin_Prj = ""
               then Prj_Tree.Root_Project.Name
               else Origin_Prj);
         begin
            Requested_Projects.Insert (Prj_Name);
         end;
      end if;

      for Prj_Name of Requested_Projects loop
         Iterate_Projects
           (Lookup_Project (Prj_Name),
            Process_Project'Access,
            Standard.Switches.Recursive_Projects);
      end loop;
   end Build_Prj_Map;

   --------------------
   -- Build_Unit_Map --
   --------------------

   procedure Build_Unit_Map (Override_Units : Inputs.Inputs_Type) is
      use type Ada.Containers.Count_Type;

      Units_Specified : constant Boolean := Length (Override_Units) > 0;
      --  Whether the user requested a specific set of units of interest
      --  through the --units command-line argument.

      Requested_Units : Unit_Name_Sets.Set;
      --  Lower-cased unit names from Override_Units for efficient lookup

      procedure Process_Override_Units (Unit : String);
      --  Register Unit to Requested_Units and add a filler entry to Unit_Map
      --  for it.

      procedure Process_Project (Project : Project_Type);
      --  Compute the list of units of interest in Project and call
      --  Enumerate_In_Single_Projects for Project.

      ----------------------------
      -- Process_Override_Units --
      ----------------------------

      procedure Process_Override_Units (Unit : String) is
         Ignored_Cur : Unit_Maps.Cursor;
      begin
         Requested_Units.Include (To_Lower (Unit));
         Add_Unit (Unit_Map, Ignored_Cur, Unit);
      end Process_Override_Units;

      ---------------------
      -- Process_Project --
      ---------------------

      procedure Process_Project (Project : Project_Type) is
         Inc_Units         : Unit_Maps.Map;
         Inc_Units_Defined : Boolean := False;
         --  Units to be included, as specified in project

         Exc_Units : Unit_Maps.Map;
         --  Units to be excluded, as specified in project

         Has_Unit_Selection_Attributes : Boolean := False;
         --  Whether this project defines attributes to select units of
         --  interest.

         Has_One_Unit_Of_Interest : Boolean := False;
         --  Whether this project has at least one unit of interest
      begin
         --  Unless the set of units of interest is overriden by --units, go
         --  through all units, taking into account Units and Excluded_Units
         --  attributes in the Coverage project package.

         if not Units_Specified then

            Units_From_Project
              (Project,
               List_Attr      => Units,
               List_File_Attr => Units_List,
               Units          => Inc_Units,
               Defined        => Inc_Units_Defined);

            declare
               Exc_Units_Defined : Boolean;
            begin
               Units_From_Project
                 (Project,
                  List_Attr       => Excluded_Units,
                  List_File_Attr  => Excluded_Units_List,
                  Units           => Exc_Units,
                  Defined         => Exc_Units_Defined);

               Has_Unit_Selection_Attributes :=
                  Inc_Units_Defined or else Exc_Units_Defined;
            end;
         end if;

         --  If Project does not specify units of interest thanks to project
         --  attributes, assume that all of its units are of interest.

         if not Inc_Units_Defined then
            declare
               procedure Process_Source_File
                 (Info : File_Info; Unit_Name : String);
               --  Add Unit_Name to Inc_Units

               -------------------------
               -- Process_Source_File --
               -------------------------

               procedure Process_Source_File
                 (Info : File_Info; Unit_Name : String)
               is
                  Cur : Unit_Maps.Cursor;
               begin
                  --  Never try to perform coverage on our coverage runtime
                  --  library (in one of the gnatcov_rts*.gpr projects) or on
                  --  our coverage buffer units (in user projects).

                  if Strings.Has_Prefix (Unit_Name, "gnatcov_rts.") then
                     return;
                  end if;

                  if not Units_Specified
                     or else Requested_Units.Contains (To_Lower (Unit_Name))
                  then
                     Add_Unit (Inc_Units, Cur, Unit_Name);
                     Inc_Units.Reference (Cur).Is_Subunit :=
                        Info.Unit_Part = Unit_Separate;
                  end if;
               end Process_Source_File;

            begin
               Iterate_Source_Files
                 (Project, Process_Source_File'Access, Recursive => False);
               Inc_Units_Defined := True;
            end;
         end if;

         --  Register as units of interest all units in Inc_Units which are not
         --  in Exc_Units.

         for Cur in Inc_Units.Iterate loop
            declare
               use Unit_Maps;
               K : constant String := Key (Cur);
            begin
               if not Exc_Units.Contains (K) then
                  declare
                     Info : Unit_Info := Element (Cur);
                  begin
                     Has_One_Unit_Of_Interest := True;
                     Info.Present_In_Projects := True;
                     Unit_Map.Include (K, Info);
                  end;
               end if;
            end;
         end loop;

         --  Compute whether this project contributes to the selection of units
         --  of interest.

         Prj_Map.Reference (Project.Name).Has_Units_Of_Interest :=
           (Has_One_Unit_Of_Interest
            or else (not Units_Specified
                     and then Has_Unit_Selection_Attributes));
      end Process_Project;

   --  Start of processing for Build_Unit_Map

   begin
      --  Create filler map entries for requested units

      Inputs.Iterate (Override_Units, Process_Override_Units'Access);

      --  Now go through all selected projects to find units of interest

      for Prj_Info of Prj_Map loop
         Process_Project (Prj_Info.Project);
      end loop;

      if Unit_Map.Is_Empty then
         Warn ("no unit of interest");
      end if;

      --  Warn about units of interest that don't belong to any project of
      --  interest. Given that we check that units exist when processing
      --  project attributes (Units, Excluded_Units, etc.), this can only
      --  happen for unit names from Override_Units, i.e. from the --units
      --  command-line argument.

      for Cur in Unit_Map.Iterate loop
         declare
            Info : Unit_Info renames Unit_Map.Reference (Cur);
         begin
            if not Info.Present_In_Projects then
               Warn ("no unit " & To_String (Info.Original_Name) & " (from"
                     & " --units) in the projects of interest");
               Info.Warned_About_Missing_Info := True;
            end if;
         end;
      end loop;

      --  Warn about projects of interest that don't contribute to the
      --  selection of units of interest. Do this only in non-recursive mode as
      --  --recursive selects too many projects to make it practical for users
      --  to select only the projects that provide units of interest: the goal
      --  of this warning is to help users, pointing at "useless" projects.

      if not Standard.Switches.Recursive_Projects then
         for Prj_Info of Prj_Map loop
            if not Prj_Info.Has_Units_Of_Interest then
               Warn ("project " & Prj_Info.Project.Name
                     & " provides no unit of interest");
            end if;
         end loop;
      end if;
   end Build_Unit_Map;

   -----------------------
   -- List_From_Project --
   -----------------------

   procedure List_From_Project
     (Prj            : Project_Type;
      List_Attr      : List_Attribute;
      List_File_Attr : String_Attribute;
      Process_Item   : access procedure (Attr, Item : String);
      Defined        : out Boolean)
   is
      LA  : constant Attribute_Pkg_List := +List_Attr;
      LFA : constant Attribute_Pkg_String := +List_File_Attr;
   begin
      --  We check each attribute in sequence and the set we're filling
      --  is "defined" as soon as one is set explicitly.

      Defined := False;

      if Has_Attribute (Prj, LA) then
         Defined := True;
         declare
            Attr            : constant String := +List_Attr;
            List_Attr_Value : String_List_Access :=
              Attribute_Value (Prj, LA);
         begin
            for J in List_Attr_Value'Range loop
               Process_Item (Attr, List_Attr_Value (J).all);
               Free (List_Attr_Value (J));
            end loop;
            Free (List_Attr_Value);
         end;
      end if;

      if Has_Attribute (Prj, LFA) then
         Defined := True;
         declare
            Attr                 : constant String := +List_File_Attr;
            List_File_Attr_Value : constant String :=
              Attribute_Value (Prj, LFA);

            procedure Process_Item_Wrapper (Item : String);
            --  Wrapper around Process_Item for each file item

            --------------------------
            -- Process_Item_Wrapper --
            --------------------------

            procedure Process_Item_Wrapper (Item : String) is
            begin
               Process_Item.all (Attr, Item);
            end Process_Item_Wrapper;

         begin
            Read_List_From_File
              (+Full_Name
                 (Create_From_Base
                    (Base_Name => +List_File_Attr_Value,
                     Base_Dir  => Dir_Name (Project_Path (Prj)))),
               Process_Item_Wrapper'Access);
         end;
      end if;
   end List_From_Project;

   ------------------------
   -- Units_From_Project --
   ------------------------

   procedure Units_From_Project
     (Prj            : Project_Type;
      List_Attr      : List_Attribute;
      List_File_Attr : String_Attribute;
      Units          : out Unit_Maps.Map;
      Defined        : out Boolean)
   is
      Units_Present : Unit_Name_Sets.Set;
      --  Set of units present in Prj

      procedure Add_Unit (Attr, Item : String);
      --  Add Item to Units

      procedure Process_Source_File (Info : File_Info; Unit_Name : String);
      --  Add Unit_Name to Units_Present

      --------------
      -- Add_Unit --
      --------------

      procedure Add_Unit (Attr, Item : String) is
         Unit_Name   : constant String := To_Lower (Item);
         Ignored_Cur : Unit_Maps.Cursor;
      begin
         if Units_Present.Contains (Unit_Name) then
            Add_Unit (Units, Ignored_Cur, Item);
         else
            Warn ("no unit " & Item & " in project " & Prj.Name
                  & " (" & Attr & " attribute)");
         end if;
      end Add_Unit;

      -------------------------
      -- Process_Source_File --
      -------------------------

      procedure Process_Source_File (Info : File_Info; Unit_Name : String) is
         pragma Unreferenced (Info);
      begin
         Units_Present.Include (Unit_Name);
      end Process_Source_File;

   --  Start of processing for Units_From_Project

   begin
      --  Initialize Units_Present. Use the unit name for languages featuring
      --  this notion (Ada) and use the source file name otherwise (i.e. for C
      --  sources).

      Iterate_Source_Files
        (Prj, Process_Source_File'Access, Recursive => True);

      --  Now go through all units referenced by project attributes

      List_From_Project
        (Prj, List_Attr, List_File_Attr, Add_Unit'Access, Defined);
   end Units_From_Project;

   -----------------------
   -- Load_Root_Project --
   -----------------------

   procedure Load_Root_Project
     (Prj_Name                   : String;
      Target, Runtime, CGPR_File : GNAT.Strings.String_Access;
      Override_Units             : Inputs.Inputs_Type;
      From_Driver                : Boolean := False)
   is
   begin
      if Prj_Tree /= null then
         Fatal_Error ("only one root project can be specified");
      end if;

      --  Allow activation of GNATcoll debug traces via configuration file,
      --  prior to initializing the project subsystem.

      GNATCOLL.Traces.Parse_Config_File (Filename => No_File);

      pragma Assert (Env = null);
      Initialize (Target, Runtime, CGPR_File);
      pragma Assert (Env /= null);

      if Obj_Subdir /= Null_Unbounded_String then
         Env.Set_Object_Subdir (+To_String (Obj_Subdir));
      end if;

      Prj_Tree := new Project_Tree;
      begin
         Prj_Tree.Load
           (Root_Project_Path => Create (+Prj_Name),
            Env               => Env,
            Packages_To_Check => Coverage_Package_List'Access,
            Errors            => Outputs.Warning_Or_Error'Access);
      exception
         when Invalid_Project =>
            Free (Prj_Tree);
            Fatal_Error ("Could not load the project file, aborting.");
      end;

      if Obj_Subdir /= Null_Unbounded_String then
         Env.Set_Object_Subdir (+To_String (Obj_Subdir));
      end if;

      --  If we were asked only to load the project file, stop there (i.e.
      --  before computing the list of projects/units of interest).

      if From_Driver then
         return;
      end if;

      if not Externally_Built_Projects_Processing_Enabled
         and then Prj_Tree.Root_Project.Externally_Built
      then
         Fatal_Error
           ("Root project is marked as externally built, while externally"
            & " built projects are ignored by default. Consider using"
            & " --externally-built-projects.");
      end if;

      Build_Prj_Map;
      Build_Unit_Map (Override_Units);
   end Load_Root_Project;

   -----------------------
   -- Is_Project_Loaded --
   -----------------------

   function Is_Project_Loaded return Boolean is
   begin
      return Prj_Tree /= null;
   end Is_Project_Loaded;

   ---------------------------
   -- Root_Project_Filename --
   ---------------------------

   function Root_Project_Filename return String is
   begin
      return +Prj_Tree.Root_Project.Project_Path.Full_Name;
   end Root_Project_Filename;

   --------------------------------
   -- Get_Single_Main_Executable --
   --------------------------------

   function Get_Single_Main_Executable return String is
      Mains : constant Main_Source_File_Array :=
         Enumerate_Mains (GNATCOLL.Projects.Root_Project (Prj_Tree.all));
   begin
      if Mains'Length /= 1 then
         return "";
      end if;

      declare
         M         : Main_Source_File renames Mains (Mains'First);
         Exec_Name : constant Filesystem_String := M.Project.Executable_Name
           (File => M.File.Base_Name, Include_Suffix => True);
         Exec_Dir  : constant Virtual_File :=
            M.Project.Executables_Directory;
         Result    : constant Virtual_File :=
            Create_From_Dir (Exec_Dir, Exec_Name);
      begin
         return +Full_Name (Result);
      end;
   end Get_Single_Main_Executable;

   ---------------------
   -- Enumerate_Mains --
   ---------------------

   function Enumerate_Mains
     (Root_Project : Project_Type;
      Language     : String := "") return Main_Source_File_Array
   is
      Lower_Language : constant String := To_Lower (Language);

      package Main_Source_File_Vectors is new Ada.Containers.Vectors
        (Positive, Main_Source_File);
      Mains : Main_Source_File_Vectors.Vector;

      procedure Enumerate_Mains (Project : Project_Type);
      --  Append to Mains the list of main source files found in Project

      ---------------------
      -- Enumerate_Mains --
      ---------------------

      procedure Enumerate_Mains (Project : Project_Type) is
         Src_Files : File_Array_Access :=
            Project.Extended_Projects_Source_Files;
      begin
         for F of Src_Files.all loop
            declare
               Name : constant Filesystem_String := Base_Name (F);
            begin
               if Project.Is_Main_File (Name)
                  and then (Language = ""
                            or else To_Lower (Prj_Tree.Info (F).Language)
                                    = Lower_Language)
               then
                  Mains.Append ((File => F, Project => Project));
               end if;
            end;
         end loop;
         Unchecked_Free (Src_Files);
      end Enumerate_Mains;

   --  Start of processing for Enumerate_Mains

   begin
      Iterate_Projects (Root_Project, Enumerate_Mains'Access, True);
      return Result : Main_Source_File_Array (Mains.First_Index
                                              .. Mains.Last_Index)
      do
         for I in Result'Range loop
            Result (I) := Mains.Element (I);
         end loop;
      end return;
   end Enumerate_Mains;

   -------------------------
   -- Enumerate_Ada_Mains --
   -------------------------

   function Enumerate_Ada_Mains return Main_Source_File_Array is
   begin
      return Enumerate_Mains (Prj_Tree.Root_Project, "ada");
   end Enumerate_Ada_Mains;

   ----------------
   -- Output_Dir --
   ----------------

   function Output_Dir return String is
   begin
      return +Prj_Tree.Root_Project.Object_Dir.Full_Name;
   end Output_Dir;

   --------------
   -- Switches --
   --------------

   function Switches (Op : String) return String_List_Access is
   begin
      return Attribute_Value
        (Prj_Tree.Root_Project, +Switches, Index => Op);
   end Switches;

   -----------------
   -- Set_Subdirs --
   -----------------

   procedure Set_Subdirs (Subdir : String) is
   begin
      Obj_Subdir := To_Unbounded_String (Subdir);

      --  The --subdirs switch is relevant only if projects are used, otherwise
      --  it can safely be ignored. If projects are not loaded yet, the
      --  subdirectory will be used anyway thanks to Obj_Subdir.

      if Env /= null then
         Env.Set_Object_Subdir (+Subdir);
      end if;
   end Set_Subdirs;

   -------------------------------------------------
   -- Enable_Externally_Built_Projects_Processing --
   -------------------------------------------------

   procedure Enable_Externally_Built_Projects_Processing is
   begin
      Externally_Built_Projects_Processing_Enabled := True;
   end Enable_Externally_Built_Projects_Processing;

   ------------------
   -- Project_Name --
   ------------------

   function Project_Name (Source_Name : String) return String is
      F_Info : constant File_Info    := Prj_Tree.Info (Create (+Source_Name));
      Prj    : constant Project_Type := F_Info.Project;
   begin
      return (if Prj /= No_Project then Prj.Name else "");
   end Project_Name;

   ------------
   -- Target --
   ------------

   function Target return String is
   begin
      return Get_Target (Prj_Tree.Root_Project);
   end Target;

   -------------
   -- Runtime --
   -------------

   function Runtime return String is
   begin
      return Get_Runtime (Prj_Tree.Root_Project);
   end Runtime;

   ------------------------------------
   -- Enumerate_Ignored_Source_Files --
   ------------------------------------

   procedure Enumerate_Ignored_Source_Files
     (Process : access procedure (Source_File : String))
   is
      procedure Enumerate (Prj : Project_Type);
      --  Call Process on all ignored source files referenced by the
      --  Ignored_Source_Files(_List) project attributes.

      procedure Process_Wrapper (Attr, Source_File : String);
      --  Wrapper fo Process

      Dummy : Boolean;

      ---------------
      -- Enumerate --
      ---------------

      procedure Enumerate (Prj : Project_Type) is
      begin
         List_From_Project
           (Prj,
            Ignored_Source_Files,
            Ignored_Source_Files_List,
            Process_Wrapper'Access,
            Dummy);
      end Enumerate;

      ---------------------
      -- Process_Wrapper --
      ---------------------

      procedure Process_Wrapper (Attr, Source_File : String) is
         pragma Unreferenced (Attr);
      begin
         Process.all (Source_File);
      end Process_Wrapper;

   --  Start of processing for Enumerate_Ignored_Source_Files

   begin
      for Prj_Info of Prj_Map loop
         Iterate_Projects
           (Root_Project => Prj_Info.Project,
            Process      => Enumerate'Access,
            Recursive    => Standard.Switches.Recursive_Projects);
      end loop;
   end Enumerate_Ignored_Source_Files;

   --------------
   -- Finalize --
   --------------

   procedure Finalize is
   begin
      if Prj_Tree /= null then
         GNATCOLL.Projects.Aux.Delete_All_Temp_Files (Prj_Tree.Root_Project);
      end if;
   end Finalize;

   -------------
   -- Project --
   -------------

   function Project return GNATCOLL.Projects.Project_Tree_Access is
   begin
      return Prj_Tree;
   end Project;

end Project;
