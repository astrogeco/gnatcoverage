------------------------------------------------------------------------------
--                                                                          --
--                               GNATcoverage                               --
--                                                                          --
--                     Copyright (C) 2008-2012, AdaCore                     --
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

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Interfaces; use Interfaces;
with Ppc_Descs; use Ppc_Descs;
with Ppc_Opcodes; use Ppc_Opcodes;
with Hex_Images; use Hex_Images;
with Ada.Command_Line; use Ada.Command_Line;

procedure Ppc_Genopc is
   procedure Usage is
   begin
      Put_Line ("usage: "
                  & Command_Name & " [--regenerate | --disa-opcodes ]");
      Set_Exit_Status (Failure);
   end Usage;

   type Action_Type is (Action_Regenerate,
                        Action_Disa_Opcodes);
   Action : Action_Type := Action_Disa_Opcodes;

   --  If no -1, index of the corresponding generic mnemonic.
   Simplified : array (Natural range Ppc_Insns'Range) of Integer
     := (others => -1);

   Masks : array (Ppc_Insns'Range) of Unsigned_32;

   --  Maximum length of instructions name.
   Max_Len : Natural;
begin
   if Argument_Count > 1 then
      Usage;
      return;
   elsif Argument_Count = 1 then
      declare
         Arg : constant String := Argument (1);
      begin
         if Arg = "--regenerate" then
            Action := Action_Regenerate;
         elsif Arg = "--disa-opcodes" then
            Action := Action_Disa_Opcodes;
         else
            Usage;
            return;
         end if;
      end;
   end if;

   --  Compute Max_Len
   for I in Ppc_Insns'Range loop
      Max_Len := Natural'Max (Max_Len, Ppc_Insns (I).Name'Length);
   end loop;

   --  Compute Masks.
   for I in Ppc_Insns'Range loop
      declare
         Insn : Ppc_Insn_Descr renames Ppc_Insns (I);
         Mask : Unsigned_32;
      begin
         --  Compute the mask.
         Mask := 0;
         for J in Insn.Fields'Range loop
            exit when Insn.Fields (J) = F_Eof;
            Mask := Mask or Get_Mask (Insn.Fields (J));
         end loop;

         pragma Assert ((Insn.Insn and Mask) = 0);
         Masks (I) := not Mask;
      end;
   end loop;

   --  Fill Simplified.
   declare
      Last : Natural := Ppc_Insns'Last;
   begin
      for I in reverse Ppc_Insns'First .. Ppc_Insns'Last - 1 loop
         if (Ppc_Insns (I).Insn and Masks (Last)) = Ppc_Insns (Last).Insn then
            Simplified (I) := Last;
         else
            Last := I;
         end if;
      end loop;
   end;

   --  Check instructions are corresctly ordered.
   --  (only done for non-simplified one).
   declare
      Last : Unsigned_32;
   begin
      Last := Ppc_Insns (Ppc_Insns'First).Insn;

      for I in Ppc_Insns'First + 1 .. Ppc_Insns'Last loop
         if Simplified (I) < 0 then
            if Ppc_Insns (I).Insn <= Last then
               Put_Line (Standard_Error,
                         "Instruction " & Ppc_Insns (I).Name.all
                           & " is not correctly ordered");
               raise Program_Error;
            end if;
            Last := Ppc_Insns (I).Insn;
         end if;
      end loop;
   end;

   if Action = Action_Disa_Opcodes then
      --  Output ppc_disopc.tmpl
      declare
         F : File_Type;
      begin
         Open (F, In_File, "ppc_disopc.tmpl");
         loop
            declare
               L : constant String := Get_Line (F);
            begin
               exit when L = "end Ppc_Disopc;";
               Put_Line (L);
            end;
         end loop;
         Close (F);
      end;
      Put_Line ("   type Ppc_Insn_Descr is record");
      Put_Line ("      Name : String (1 .." & Natural'Image (Max_Len) & ");");
      Put_Line ("      Insn : Unsigned_32;");
      Put_Line ("      Mask : Unsigned_32;");
      Put_Line ("      Fields : Ppc_Fields_Arr;");
      Put_Line ("   end record;");
      New_Line;
      Put_Line ("   Ppc_Insns : constant array (Natural range <>) of "
                  & "Ppc_Insn_Descr :=");
      Put_Line ("     (");
   end if;

   --  Generate the instruction table.
   for I in Ppc_Insns'Range loop
      declare
         Insn : Ppc_Insn_Descr renames Ppc_Insns (I);

         function Get_Field (Field : Ppc_Fields) return Unsigned_32 is
         begin
            return Get_Field (Field, Insn.Insn);
         end Get_Field;

         V : Unsigned_32;

         procedure Print_Field_Always (Field : Ppc_Fields; Name : String)
         is
            F : constant Unsigned_32 := Get_Field (Field);
         begin
            if Field /= F_OPC then
               Put (" + ");
            end if;
            Put (Natural (F), 0);
            Put (" * S_" & Name);
            V := V and not Get_Mask (Field);
         end Print_Field_Always;

         procedure Print_Field_If_Nonzero (Field : Ppc_Fields; Name : String)
         is
            F : constant Unsigned_32 := Get_Field (Field);
         begin
            if F = 0 then
               return;
            end if;
            Print_Field_Always (Field, Name);
         end Print_Field_If_Nonzero;

         function Has_Field (Index : Natural; Field : Ppc_Fields)
                            return Boolean is
         begin
            for J in Ppc_Insns (Index).Fields'Range loop
               if Ppc_Insns (Index).Fields (J) = Field then
                  return True;
               end if;
            end loop;
            return False;
         end Has_Field;

         procedure Print_Field_If_Exist (Field : Ppc_Fields; Name : String)
         is
            Prim : Integer;
         begin
            Prim := Simplified (I);
            if Prim < 0 then
               Prim := I;
            end if;
            if Has_Field (Prim, Field) then
               Print_Field_Always (Field, Name);
            end if;
         end Print_Field_If_Exist;

         procedure Print_Field_If_Not_Exist (Field : Ppc_Fields; Name : String)
         is
         begin
            if not Has_Field (I, Field) then
               Print_Field_If_Nonzero (Field, Name);
            end if;
         end Print_Field_If_Not_Exist;

         procedure Print_Opcode is
         begin
            V := Insn.Insn;

            Print_Field_Always (F_OPC, "OPC");
            Print_Field_If_Nonzero (F_XO, "XO");
            if Simplified (I) >= 0 then
               Print_Field_If_Exist (F_BO, "BO");
               Print_Field_If_Exist (F_BI, "BI");
               Print_Field_If_Exist (F_Spr, "SPR");
               Print_Field_If_Exist (F_LK, "LK");
            else
               Print_Field_If_Not_Exist (F_Rc, "RC");
            end if;
            if V /= 0 then
               Put_Line (" XXX");
               raise Program_Error;
            end if;
         end Print_Opcode;

      begin
         if I /= Ppc_Insns'First then
            Put_Line (",");
         end if;

         if Action = Action_Disa_Opcodes then
            Put ("      (""" & Insn.Name.all
                   & (1 .. Max_Len - Insn.Name'Length => ' ') & """,");
         else
            Put ("      (new S'(""" & Insn.Name.all & """),");
         end if;
         if Simplified (I) >= 0 then
            Put ("  -- Simplified mnemonic");
         end if;
         New_Line;

         Put ("       ");
         Print_Opcode;
         Put_Line (",");

         if Action = Action_Disa_Opcodes then
            Put ("       16#");
            Put (Hex_Image (Masks (I)));
            Put_Line ("#,");
         end if;

         Put ("       (");
         for J in Insn.Fields'Range loop
            exit when Insn.Fields (J) = F_Eof;
            Put (Ppc_Fields'Image (Insn.Fields (J)));
            Put (", ");
         end loop;
         Put ("others => F_Eof))");
      end;
   end loop;

   if Action = Action_Disa_Opcodes then

      --  A sentinel.
      Put_Line (",");
      Put_Line ("      ("""  & (1 .. Max_Len => '-') & """,  --  Sentinel");
      Put_Line ("       63 * S_OPC,");
      Put_Line ("       16#00000000#,");
      Put_Line ("       (others => F_Eof))");

      Put_Line ("     );");

      --  Generate the Index table.
      --  This table speed-up the search by having to first instruction
      --  that correspond to the OPC.
      declare
         Firsts : array (Natural range 0 .. 64) of Integer := (others => -1);
         Opc : Natural;
         Last : Natural := 0;
      begin
         for I in Ppc_Insns'Range loop
            Opc := Natural (Get_Field (F_OPC, Ppc_Insns (I).Insn));
            if Firsts (Opc) < 0 then
               Firsts (Opc) := I;

               --  Trick for 'with update' instructions.
               if Last = Opc - 1
                 and then Ppc_Insns (I - 1).Fields (0) = F_U
               then
                  Firsts (Last) := I - 1;
                  Last := Last + 2;
               else
                  while Last < Opc loop
                     Firsts (Last) := I;
                     Last := Last + 1;
                  end loop;
                  Last := Last + 1;
               end if;
            end if;
         end loop;
         Firsts (Firsts'Last) := Ppc_Insns'Last + 1;

         New_Line;
         Put_Line
           ("   Ppc_Opc_Index : constant array (0 .. 64) of Integer :=");
         Put_Line ("     (");
         for I in Firsts'Range loop
            Put ("     ");
            Put (Natural'Image (I) & " => " & Integer'Image (Firsts (I)));
            if I /= Firsts'Last then
               Put (",");
            end if;
            New_Line;
         end loop;
         Put_Line ("     );");
      end;
      New_Line;
      Put_Line ("end Ppc_Disopc;");
   else
      New_Line;
   end if;
end Ppc_Genopc;
