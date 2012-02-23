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
pragma Restrictions (No_Elaboration_Code);

with Interfaces; use Interfaces;
with Ppc_Descs; use Ppc_Descs;

package Ppc_Opcodes is

   type String_Cst_Acc is access constant String;

   type Ppc_Fields_Arr is array (0 .. 5) of Ppc_Fields;

   type Ppc_Insn_Descr is record
      Name : String_Cst_Acc;
      Insn : Unsigned_32;
      Fields : Ppc_Fields_Arr;
   end record;

   subtype S is String;

   type Ppc_Insns_Descs is array (Natural range <>) of Ppc_Insn_Descr;

   Ppc_Insns : constant Ppc_Insns_Descs :=
     (
      (new S'("twi"),
       3 * S_OPC,
       (F_TO, F_A, F_SIMM, others => F_Eof)),
      (new S'("mulli"),
       7 * S_OPC,
       (F_D, F_A, F_SIMM, others => F_Eof)),
      (new S'("subfic"),
       8 * S_OPC,
       (F_D, F_A, F_SIMM, others => F_Eof)),
      (new S'("cmpli"),
       10 * S_OPC,
       (F_L, F_CrfD, F_A, F_UIMM, others => F_Eof)),
      (new S'("cmpi"),
       11 * S_OPC,
       (F_L, F_CrfD, F_A, F_SIMM, others => F_Eof)),
      (new S'("addic"),
       12 * S_OPC,
       (F_D, F_A, F_SIMM, others => F_Eof)),
      (new S'("addic."),
       13 * S_OPC,
       (F_D, F_A, F_SIMM, others => F_Eof)),
      (new S'("li"),  -- Simplified mnemonic
       14 * S_OPC,
       (F_D, F_SIMM, others => F_Eof)),
      (new S'("addi"),
       14 * S_OPC,
       (F_D, F_A, F_SIMM, others => F_Eof)),
      (new S'("lis"),  -- Simplified mnemonic
       15 * S_OPC,
       (F_D, F_SIMM, others => F_Eof)),
      (new S'("addis"),
       15 * S_OPC,
       (F_D, F_A, F_SIMM, others => F_Eof)),
      (new S'("blt"),  -- Simplified mnemonic
       16 * S_OPC + 12 * S_BO + 0 * S_BI + 0 * S_LK,
       (F_AA, F_LK, F_Br_Hint, F_CrfS, F_BD, others => F_Eof)),
      (new S'("bgt"),  -- Simplified mnemonic
       16 * S_OPC + 12 * S_BO + 1 * S_BI + 0 * S_LK,
       (F_AA, F_LK, F_Br_Hint, F_CrfS, F_BD, others => F_Eof)),
      (new S'("beq"),  -- Simplified mnemonic
       16 * S_OPC + 12 * S_BO + 2 * S_BI + 0 * S_LK,
       (F_AA, F_LK, F_Br_Hint, F_CrfS, F_BD, others => F_Eof)),
      (new S'("bge"),  -- Simplified mnemonic
       16 * S_OPC + 4 * S_BO + 0 * S_BI + 0 * S_LK,
       (F_AA, F_LK, F_Br_Hint, F_CrfS, F_BD, others => F_Eof)),
      (new S'("ble"),  -- Simplified mnemonic
       16 * S_OPC + 4 * S_BO + 1 * S_BI + 0 * S_LK,
       (F_AA, F_LK, F_Br_Hint, F_CrfS, F_BD, others => F_Eof)),
      (new S'("bne"),  -- Simplified mnemonic
       16 * S_OPC + 4 * S_BO + 2 * S_BI + 0 * S_LK,
       (F_AA, F_LK, F_Br_Hint, F_CrfS, F_BD, others => F_Eof)),
      (new S'("bc"),
       16 * S_OPC,
       (F_AA, F_LK, F_BO, F_BI, F_BD, others => F_Eof)),
      (new S'("sc"),
       17 * S_OPC + 1 * S_XO,
       (others => F_Eof)),
      (new S'("b"),
       18 * S_OPC,
       (F_AA, F_LK, F_LI, others => F_Eof)),
      (new S'("mcrf"),
       19 * S_OPC,
       (F_CrfD, F_CrfS, others => F_Eof)),
      (new S'("blr"),  -- Simplified mnemonic
       19 * S_OPC + 16 * S_XO + 20 * S_BO + 0 * S_BI + 0 * S_LK,
       (others => F_Eof)),
      (new S'("bclr"),
       19 * S_OPC + 16 * S_XO,
       (F_LK, F_BO, F_BI, others => F_Eof)),
      (new S'("crnor"),
       19 * S_OPC + 33 * S_XO,
       (F_CrbD, F_CrbA, F_CrbB, others => F_Eof)),
      (new S'("rfi"),
       19 * S_OPC + 50 * S_XO,
       (others => F_Eof)),
      (new S'("crandc"),
       19 * S_OPC + 129 * S_XO,
       (F_CrbD, F_CrbA, F_CrbB, others => F_Eof)),
      (new S'("isync"),
       19 * S_OPC + 150 * S_XO,
       (others => F_Eof)),
      (new S'("crxor"),
       19 * S_OPC + 193 * S_XO,
       (F_CrbD, F_CrbA, F_CrbB, others => F_Eof)),
      (new S'("crnand"),
       19 * S_OPC + 225 * S_XO,
       (F_CrbD, F_CrbA, F_CrbB, others => F_Eof)),
      (new S'("crand"),
       19 * S_OPC + 257 * S_XO,
       (F_CrbD, F_CrbA, F_CrbB, others => F_Eof)),
      (new S'("creqv"),
       19 * S_OPC + 289 * S_XO,
       (F_CrbD, F_CrbA, F_CrbB, others => F_Eof)),
      (new S'("crorc"),
       19 * S_OPC + 417 * S_XO,
       (F_CrbD, F_CrbA, F_CrbB, others => F_Eof)),
      (new S'("cror"),
       19 * S_OPC + 449 * S_XO,
       (F_CrbD, F_CrbA, F_CrbB, others => F_Eof)),
      (new S'("bctrl"),  -- Simplified mnemonic
       19 * S_OPC + 528 * S_XO + 20 * S_BO + 0 * S_BI + 1 * S_LK,
       (others => F_Eof)),
      (new S'("bcctr"),
       19 * S_OPC + 528 * S_XO,
       (F_LK, F_BO, F_BI, others => F_Eof)),
      (new S'("rlwimi"),
       20 * S_OPC,
       (F_Rc, F_A, F_S, F_SH, F_MB, F_ME, others => F_Eof)),
      (new S'("clrlwi"),  -- Simplified mnemonic
       21 * S_OPC + 31 * S_XO,
       (F_Rc, F_A, F_S, F_MB, others => F_Eof)),
      (new S'("rlwinm"),
       21 * S_OPC,
       (F_Rc, F_A, F_S, F_SH, F_MB, F_ME, others => F_Eof)),
      (new S'("rlwnm"),
       23 * S_OPC,
       (F_Rc, F_A, F_S, F_B, F_MB, F_ME, others => F_Eof)),
      (new S'("ori"),
       24 * S_OPC,
       (F_A, F_S, F_UIMM, others => F_Eof)),
      (new S'("oris"),
       25 * S_OPC,
       (F_A, F_S, F_UIMM, others => F_Eof)),
      (new S'("xori"),
       26 * S_OPC,
       (F_A, F_S, F_UIMM, others => F_Eof)),
      (new S'("xoris"),
       27 * S_OPC,
       (F_A, F_S, F_UIMM, others => F_Eof)),
      (new S'("andi."),
       28 * S_OPC,
       (F_A, F_S, F_UIMM, others => F_Eof)),
      (new S'("andis."),
       29 * S_OPC,
       (F_A, F_S, F_UIMM, others => F_Eof)),
      (new S'("cmp"),
       31 * S_OPC,
       (F_L, F_CrfD, F_A, F_B, others => F_Eof)),
      (new S'("tw"),
       31 * S_OPC + 4 * S_XO,
       (F_TO, F_A, F_B, others => F_Eof)),
      (new S'("subfc"),
       31 * S_OPC + 8 * S_XO,
       (F_OE, F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("addc"),
       31 * S_OPC + 10 * S_XO,
       (F_OE, F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("mulhwu"),
       31 * S_OPC + 11 * S_XO,
       (F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("mfcr"),
       31 * S_OPC + 19 * S_XO,
       (F_D, others => F_Eof)),
      (new S'("lwarx"),
       31 * S_OPC + 20 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("lwzx"),
       31 * S_OPC + 23 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("slw"),
       31 * S_OPC + 24 * S_XO,
       (F_Rc, F_A, F_S, F_B, others => F_Eof)),
      (new S'("cntlzw"),
       31 * S_OPC + 26 * S_XO,
       (F_Rc, F_A, F_S, others => F_Eof)),
      (new S'("and"),
       31 * S_OPC + 28 * S_XO,
       (F_Rc, F_A, F_S, F_B, others => F_Eof)),
      (new S'("cmpl"),
       31 * S_OPC + 32 * S_XO,
       (F_L, F_CrfD, F_A, F_B, others => F_Eof)),
      (new S'("subf"),
       31 * S_OPC + 40 * S_XO,
       (F_OE, F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("dcbst"),
       31 * S_OPC + 54 * S_XO,
       (F_A, F_B, others => F_Eof)),
      (new S'("lwzux"),
       31 * S_OPC + 55 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("andc"),
       31 * S_OPC + 60 * S_XO,
       (F_Rc, F_A, F_S, F_B, others => F_Eof)),
      (new S'("mulhw"),
       31 * S_OPC + 75 * S_XO,
       (F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("mfmsr"),
       31 * S_OPC + 83 * S_XO,
       (F_D, others => F_Eof)),
      (new S'("dcbf"),
       31 * S_OPC + 86 * S_XO,
       (F_A, F_B, others => F_Eof)),
      (new S'("lbzx"),
       31 * S_OPC + 87 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("neg"),
       31 * S_OPC + 104 * S_XO,
       (F_OE, F_Rc, F_D, F_A, others => F_Eof)),
      (new S'("lbzux"),
       31 * S_OPC + 119 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("nor"),
       31 * S_OPC + 124 * S_XO,
       (F_Rc, F_A, F_S, F_B, others => F_Eof)),
      (new S'("subfe"),
       31 * S_OPC + 136 * S_XO,
       (F_OE, F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("adde"),
       31 * S_OPC + 138 * S_XO,
       (F_OE, F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("mtcrf"),
       31 * S_OPC + 144 * S_XO,
       (F_CRM, F_S, others => F_Eof)),
      (new S'("mtmsr"),
       31 * S_OPC + 146 * S_XO,
       (F_S, others => F_Eof)),
      (new S'("stwcx."),
       31 * S_OPC + 150 * S_XO + 1 * S_RC,
       (F_A, F_S, F_B, others => F_Eof)),
      (new S'("stwx"),
       31 * S_OPC + 151 * S_XO,
       (F_A, F_S, F_B, others => F_Eof)),
      (new S'("stwux"),
       31 * S_OPC + 183 * S_XO,
       (F_A, F_S, F_B, others => F_Eof)),
      (new S'("subfze"),
       31 * S_OPC + 200 * S_XO,
       (F_OE, F_Rc, F_D, F_A, others => F_Eof)),
      (new S'("addze"),
       31 * S_OPC + 202 * S_XO,
       (F_OE, F_Rc, F_D, F_A, others => F_Eof)),
      (new S'("mtsr"),
       31 * S_OPC + 210 * S_XO,
       (F_Sr, F_S, others => F_Eof)),
      (new S'("stbx"),
       31 * S_OPC + 215 * S_XO,
       (F_S, F_A, F_B, others => F_Eof)),
      (new S'("subfme"),
       31 * S_OPC + 232 * S_XO,
       (F_OE, F_Rc, F_D, F_A, others => F_Eof)),
      (new S'("addme"),
       31 * S_OPC + 234 * S_XO,
       (F_OE, F_Rc, F_D, F_A, others => F_Eof)),
      (new S'("mullw"),
       31 * S_OPC + 235 * S_XO,
       (F_OE, F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("mtsrin"),
       31 * S_OPC + 242 * S_XO,
       (F_S, F_B, others => F_Eof)),
      (new S'("dcbtst"),
       31 * S_OPC + 246 * S_XO,
       (F_A, F_B, others => F_Eof)),
      (new S'("stbux"),
       31 * S_OPC + 247 * S_XO,
       (F_S, F_A, F_B, others => F_Eof)),
      (new S'("add"),
       31 * S_OPC + 266 * S_XO,
       (F_OE, F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("dcbt"),
       31 * S_OPC + 278 * S_XO,
       (F_A, F_B, others => F_Eof)),
      (new S'("lhzx"),
       31 * S_OPC + 279 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("eqv"),
       31 * S_OPC + 284 * S_XO,
       (F_Rc, F_A, F_S, F_B, others => F_Eof)),
      (new S'("tlbie"),
       31 * S_OPC + 306 * S_XO,
       (F_B, others => F_Eof)),
      (new S'("eciwx"),
       31 * S_OPC + 310 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("lhzux"),
       31 * S_OPC + 311 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("xor"),
       31 * S_OPC + 316 * S_XO,
       (F_Rc, F_A, F_S, F_B, others => F_Eof)),
      (new S'("mflr"),  -- Simplified mnemonic
       31 * S_OPC + 339 * S_XO + 256 * S_SPR,
       (F_D, others => F_Eof)),
      (new S'("mfctr"),  -- Simplified mnemonic
       31 * S_OPC + 339 * S_XO + 288 * S_SPR,
       (F_D, others => F_Eof)),
      (new S'("mfspr"),
       31 * S_OPC + 339 * S_XO,
       (F_D, F_Spr, others => F_Eof)),
      (new S'("lhax"),
       31 * S_OPC + 343 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("tlbia"),
       31 * S_OPC + 370 * S_XO,
       (others => F_Eof)),
      (new S'("mftb"),
       31 * S_OPC + 371 * S_XO,
       (F_D, F_Tbr, others => F_Eof)),
      (new S'("lhaux"),
       31 * S_OPC + 375 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("sthx"),
       31 * S_OPC + 407 * S_XO,
       (F_S, F_A, F_B, others => F_Eof)),
      (new S'("orc"),
       31 * S_OPC + 412 * S_XO,
       (F_Rc, F_A, F_S, F_B, others => F_Eof)),
      (new S'("ecowx"),
       31 * S_OPC + 438 * S_XO,
       (F_S, F_A, F_B, others => F_Eof)),
      (new S'("sthux"),
       31 * S_OPC + 439 * S_XO,
       (F_S, F_A, F_B, others => F_Eof)),
      (new S'("or"),
       31 * S_OPC + 444 * S_XO,
       (F_Rc, F_A, F_S, F_B, others => F_Eof)),
      (new S'("divwu"),
       31 * S_OPC + 459 * S_XO,
       (F_OE, F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("mtlr"),  -- Simplified mnemonic
       31 * S_OPC + 467 * S_XO + 256 * S_SPR,
       (F_S, others => F_Eof)),
      (new S'("mtctr"),  -- Simplified mnemonic
       31 * S_OPC + 467 * S_XO + 288 * S_SPR,
       (F_S, others => F_Eof)),
      (new S'("mtspr"),
       31 * S_OPC + 467 * S_XO,
       (F_Spr, F_S, others => F_Eof)),
      (new S'("dcbi"),
       31 * S_OPC + 470 * S_XO,
       (F_A, F_B, others => F_Eof)),
      (new S'("nandx"),
       31 * S_OPC + 476 * S_XO,
       (F_Rc, F_S, F_A, F_B, others => F_Eof)),
      (new S'("divw"),
       31 * S_OPC + 491 * S_XO,
       (F_OE, F_Rc, F_D, F_A, F_B, others => F_Eof)),
      (new S'("mcrxr"),
       31 * S_OPC + 512 * S_XO,
       (F_CrfD, others => F_Eof)),
      (new S'("lswx"),
       31 * S_OPC + 533 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("lwbrx"),
       31 * S_OPC + 534 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("lfsx"),
       31 * S_OPC + 535 * S_XO,
       (F_FD, F_A, F_B, others => F_Eof)),
      (new S'("srw"),
       31 * S_OPC + 536 * S_XO,
       (F_Rc, F_A, F_S, F_B, others => F_Eof)),
      (new S'("tlbsync"),
       31 * S_OPC + 566 * S_XO,
       (others => F_Eof)),
      (new S'("lfsux"),
       31 * S_OPC + 567 * S_XO,
       (F_FD, F_A, F_B, others => F_Eof)),
      (new S'("mfsr"),
       31 * S_OPC + 595 * S_XO,
       (F_D, F_Sr, others => F_Eof)),
      (new S'("lswi"),
       31 * S_OPC + 597 * S_XO,
       (F_D, F_A, F_NB, others => F_Eof)),
      (new S'("sync"),
       31 * S_OPC + 598 * S_XO,
       (others => F_Eof)),
      (new S'("lfdx"),
       31 * S_OPC + 599 * S_XO,
       (F_FD, F_A, F_B, others => F_Eof)),
      (new S'("lfdux"),
       31 * S_OPC + 631 * S_XO,
       (F_FD, F_A, F_B, others => F_Eof)),
      (new S'("mfsrin"),
       31 * S_OPC + 659 * S_XO,
       (F_D, F_B, others => F_Eof)),
      (new S'("stswx"),
       31 * S_OPC + 661 * S_XO,
       (F_S, F_A, F_B, others => F_Eof)),
      (new S'("stwbrx"),
       31 * S_OPC + 662 * S_XO,
       (F_S, F_A, F_B, others => F_Eof)),
      (new S'("stfsx"),
       31 * S_OPC + 663 * S_XO,
       (F_FS, F_A, F_B, others => F_Eof)),
      (new S'("stfsux"),
       31 * S_OPC + 695 * S_XO,
       (F_FS, F_A, F_B, others => F_Eof)),
      (new S'("stswi"),
       31 * S_OPC + 725 * S_XO,
       (F_S, F_A, F_NB, others => F_Eof)),
      (new S'("stfdx"),
       31 * S_OPC + 727 * S_XO,
       (F_FS, F_A, F_B, others => F_Eof)),
      (new S'("dcba"),
       31 * S_OPC + 758 * S_XO,
       (F_A, F_B, others => F_Eof)),
      (new S'("stfdux"),
       31 * S_OPC + 759 * S_XO,
       (F_FS, F_A, F_B, others => F_Eof)),
      (new S'("lhbrx"),
       31 * S_OPC + 790 * S_XO,
       (F_D, F_A, F_B, others => F_Eof)),
      (new S'("sraw"),
       31 * S_OPC + 792 * S_XO,
       (F_Rc, F_A, F_S, F_B, others => F_Eof)),
      (new S'("srawi"),
       31 * S_OPC + 824 * S_XO,
       (F_Rc, F_A, F_S, F_SH, others => F_Eof)),
      (new S'("eieio"),
       31 * S_OPC + 854 * S_XO,
       (others => F_Eof)),
      (new S'("sthbrx"),
       31 * S_OPC + 918 * S_XO,
       (F_S, F_A, F_B, others => F_Eof)),
      (new S'("extsh"),
       31 * S_OPC + 922 * S_XO,
       (F_Rc, F_A, F_S, others => F_Eof)),
      (new S'("extsb"),
       31 * S_OPC + 954 * S_XO,
       (F_A, F_S, others => F_Eof)),
      (new S'("icbi"),
       31 * S_OPC + 982 * S_XO,
       (F_A, F_B, others => F_Eof)),
      (new S'("stfiwx"),
       31 * S_OPC + 983 * S_XO,
       (F_FS, F_A, F_B, others => F_Eof)),
      (new S'("dcbz"),
       31 * S_OPC + 1014 * S_XO,
       (F_A, F_B, others => F_Eof)),
      (new S'("lwz"),
       32 * S_OPC,
       (F_U, F_D, F_Disp, F_A, others => F_Eof)),
      (new S'("lbz"),
       34 * S_OPC,
       (F_U, F_D, F_Disp, F_A, others => F_Eof)),
      (new S'("stw"),
       36 * S_OPC,
       (F_U, F_S, F_Disp, F_A, others => F_Eof)),
      (new S'("stb"),
       38 * S_OPC,
       (F_U, F_S, F_Disp, F_A, others => F_Eof)),
      (new S'("lhz"),
       40 * S_OPC,
       (F_U, F_D, F_Disp, F_A, others => F_Eof)),
      (new S'("lha"),
       42 * S_OPC,
       (F_U, F_D, F_Disp, F_A, others => F_Eof)),
      (new S'("sth"),
       44 * S_OPC,
       (F_U, F_S, F_Disp, F_A, others => F_Eof)),
      (new S'("lmw"),
       46 * S_OPC,
       (F_D, F_Disp, F_A, others => F_Eof)),
      (new S'("stmw"),
       47 * S_OPC,
       (F_S, F_Disp, F_A, others => F_Eof)),
      (new S'("lfs"),
       48 * S_OPC,
       (F_U, F_FD, F_Disp, F_A, others => F_Eof)),
      (new S'("lfd"),
       50 * S_OPC,
       (F_U, F_FD, F_Disp, F_A, others => F_Eof)),
      (new S'("stfs"),
       52 * S_OPC,
       (F_U, F_FS, F_Disp, F_A, others => F_Eof)),
      (new S'("stfd"),
       54 * S_OPC,
       (F_U, F_FS, F_Disp, F_A, others => F_Eof)),
      (new S'("fdivs"),
       59 * S_OPC + 18 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, others => F_Eof)),
      (new S'("fsubs"),
       59 * S_OPC + 20 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, others => F_Eof)),
      (new S'("fadds"),
       59 * S_OPC + 21 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, others => F_Eof)),
      (new S'("fsqrts"),
       59 * S_OPC + 22 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("fres"),
       59 * S_OPC + 24 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("fmuls"),
       59 * S_OPC + 25 * S_XO,
       (F_Rc, F_FD, F_FA, F_FC, others => F_Eof)),
      (new S'("fmsubs"),
       59 * S_OPC + 28 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, F_FC, others => F_Eof)),
      (new S'("fmadds"),
       59 * S_OPC + 29 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, F_FC, others => F_Eof)),
      (new S'("fnmsubs"),
       59 * S_OPC + 30 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, F_FC, others => F_Eof)),
      (new S'("fnmadds"),
       59 * S_OPC + 31 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, F_FC, others => F_Eof)),
      (new S'("fcmpu"),
       63 * S_OPC,
       (F_CrfD, F_FA, F_FB, others => F_Eof)),
      (new S'("frsp"),
       63 * S_OPC + 12 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("fctiw"),
       63 * S_OPC + 14 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("fctiwz"),
       63 * S_OPC + 15 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("fdiv"),
       63 * S_OPC + 18 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, others => F_Eof)),
      (new S'("fsub"),
       63 * S_OPC + 20 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, others => F_Eof)),
      (new S'("fadd"),
       63 * S_OPC + 21 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, others => F_Eof)),
      (new S'("fsqrt"),
       63 * S_OPC + 22 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("fsel"),
       63 * S_OPC + 23 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, F_FC, others => F_Eof)),
      (new S'("fmul"),
       63 * S_OPC + 25 * S_XO,
       (F_Rc, F_FD, F_FA, F_FC, others => F_Eof)),
      (new S'("frsqrte"),
       63 * S_OPC + 26 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("fmsub"),
       63 * S_OPC + 28 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, F_FC, others => F_Eof)),
      (new S'("fmadd"),
       63 * S_OPC + 29 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, F_FC, others => F_Eof)),
      (new S'("fnmsub"),
       63 * S_OPC + 30 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, F_FC, others => F_Eof)),
      (new S'("fnmadd"),
       63 * S_OPC + 31 * S_XO,
       (F_Rc, F_FD, F_FA, F_FB, F_FC, others => F_Eof)),
      (new S'("fcmpo"),
       63 * S_OPC + 32 * S_XO,
       (F_CrfD, F_FA, F_FB, others => F_Eof)),
      (new S'("mtfsb1"),
       63 * S_OPC + 38 * S_XO,
       (F_Rc, F_CrbD, others => F_Eof)),
      (new S'("fneg"),
       63 * S_OPC + 40 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("mcrfs"),
       63 * S_OPC + 64 * S_XO,
       (F_CrfD, F_CrfS, others => F_Eof)),
      (new S'("mtfsb0"),
       63 * S_OPC + 70 * S_XO,
       (F_Rc, F_CrbD, others => F_Eof)),
      (new S'("fmr"),
       63 * S_OPC + 72 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("mtfsfi"),
       63 * S_OPC + 134 * S_XO,
       (F_Rc, F_CrfD, F_Imm, others => F_Eof)),
      (new S'("fnabs"),
       63 * S_OPC + 136 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("fabs"),
       63 * S_OPC + 264 * S_XO,
       (F_Rc, F_FD, F_FB, others => F_Eof)),
      (new S'("mffs"),
       63 * S_OPC + 583 * S_XO,
       (F_Rc, F_D, others => F_Eof)),
      (new S'("mtfsf"),
       63 * S_OPC + 711 * S_XO,
       (F_Rc, F_Fm, F_FB, others => F_Eof))
     );
end Ppc_Opcodes;
