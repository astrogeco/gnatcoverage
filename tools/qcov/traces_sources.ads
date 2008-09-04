------------------------------------------------------------------------------
--                                                                          --
--                              Couverture                                  --
--                                                                          --
--                        Copyright (C) 2008, AdaCore                       --
--                                                                          --
-- Couverture is free software; you can redistribute it  and/or modify it   --
-- under terms of the GNU General Public License as published by the Free   --
-- Software Foundation; either version 2, or (at your option) any later     --
-- version.  Couverture is distributed in the hope that it will be useful,  --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHAN-  --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details. You  should  have  received a copy of the GNU --
-- General Public License  distributed with GNAT; see file COPYING. If not, --
-- write  to  the Free  Software  Foundation,  59 Temple Place - Suite 330, --
-- Boston, MA 02111-1307, USA.                                              --
--                                                                          --
------------------------------------------------------------------------------
with GNAT.Dynamic_Tables;
with Ada.Containers.Hashed_Maps;
with Traces;
with Traces_Elf; use Traces_Elf;

package Traces_Sources is
   --  Coverage state of a source line of code.
   type Line_State is
     (
      --  No instructions executed.
      Not_Covered,

      --  Some instructions not covered in the line.
      Partially_Covered,

      --  Covered at instructions level but there are branches partially
      --  covered.
      Covered, -- Branch_Partially_Covered

      --  All instructions executed.
      --  Only one branch and one decision taken.
      Branch_Taken,
      Branch_Fallthrough,

      --  Covered at decision level.
      Branch_Covered,

      --  Same as covered but no branches.
      Covered_No_Branch,

      --  Initial state: no code for this line.
      No_Code
      );

   --  Data associated with a SLOC.
   type Line_Info is record
      --  The coverage state.
      State : Line_State;

      --  Object code for this line.
      Lines : Addresses_Line_Chain;
   end record;

   --  Describe a source file - one element per line.
   package Source_Lines_Vectors is new GNAT.Dynamic_Tables
     (Table_Component_Type => Line_Info,
      Table_Index_Type => Natural,
      Table_Low_Bound => 1,
      Table_Initial => 16,
      Table_Increment => 100);

   subtype Source_Lines is Source_Lines_Vectors.Instance;

   --  Containers helpers.
   function Hash (El : String_Acc) return Ada.Containers.Hash_Type;
   function Equivalent (L, R : String_Acc) return Boolean;
   function Equal (L, R : Source_Lines) return Boolean;

   --  Describe all the source files.
   package Filenames_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type => String_Acc,
      Element_Type => Source_Lines,
      Hash => Hash,
      Equivalent_Keys => Equivalent,
      "=" => Equal);

   --  Find or create a new source file.
   function Find_File (Filename : String_Acc) return Filenames_Maps.Cursor;

   --  Lets know File that Line exists and add the addresses range for Info.
   --  (This knowledge comes from debugging informations).
   procedure Add_Line (File : Filenames_Maps.Cursor;
                       Line : Natural;
                       Info : Addresses_Info_Acc);

   --  Same as Add_Line but with a State.
   --  (The knowledge comes from execution traces).
   procedure Add_Line_State (File : Filenames_Maps.Cursor;
                             Line : Natural;
                             State : Traces.Trace_State);

   --  If True, Disp_Line_State will also display assembly code.
   Flag_Show_Asm : Boolean := False;

   -- If True, Disp_Line_State will also display info for files that are not
   -- found.
   Flag_Show_Missing : Boolean := False;

   --  Display source lines with status.
   procedure Disp_Line_State;

   --  Display a per file summary.
   procedure Disp_File_Summary;
end Traces_Sources;
