with Args; use Args;

package body Val is

   pragma Unsuppress (All_Checks);

   function Bool (A : Integer) return Boolean is
   begin
      -- Possible index check failure here
      if Bool_For (A) then -- # eval
         return True;  -- # true
      else
         return False; -- # false
      end if;
   end;

end;
