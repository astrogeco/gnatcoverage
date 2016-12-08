with Support, Ops; use Support, Ops;

procedure Test_Ops_Full is
   T : Integer;
   Fault : Boolean;
begin
   Div (4, 0, T, Fault);
   Assert (Fault);
   
   Div (4, 2, T, Fault);
   Assert (T = 2);
   Assert (not Fault);
end;

--# ops.adb
--  /fault/ l+ ## 0
--  /no_fault/ l+ ## 0
--  /stmt/  l+ ## 0
--  /bad_handler/ l- ## s-
