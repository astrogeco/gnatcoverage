package body Eval is

   function E_And (A, B : Boolean) return Boolean is
   begin
      loop
         exit when A and B; -- # eval :o/d:
         return False;           -- # retFalse
      end loop;
      return True;      -- # retTrue
   end;
end;
