------------------------------------------------------------------------------
--                                                                          --
--                           OCARINA COMPONENTS                             --
--                                                                          --
--        OCARINA.INSTANCES.REAL_CHECKER.QUERIES.ACCESS_PREDICATES          --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--       Copyright (C) 2009 Telecom ParisTech, 2010-2012 ESA & ISAE.        --
--                                                                          --
-- Ocarina  is free software;  you  can  redistribute  it and/or  modify    --
-- it under terms of the GNU General Public License as published by the     --
-- Free Software Foundation; either version 2, or (at your option) any      --
-- later version. Ocarina is distributed  in  the  hope  that it will be    --
-- useful, but WITHOUT ANY WARRANTY;  without even the implied warranty of  --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General --
-- Public License for more details. You should have received  a copy of the --
-- GNU General Public License distributed with Ocarina; see file COPYING.   --
-- If not, write to the Free Software Foundation, 51 Franklin Street, Fifth --
-- Floor, Boston, MA 02111-1301, USA.                                       --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable to be   --
-- covered  by the  GNU  General  Public  License. This exception does not  --
-- however invalidate  any other reasons why the executable file might be   --
-- covered by the GNU Public License.                                       --
--                                                                          --
--                 Ocarina is maintained by the TASTE project               --
--                      (taste-users@lists.tuxfamily.org)                   --
--                                                                          --
------------------------------------------------------------------------------

with Ocarina.ME_AADL.AADL_Instances.Nodes;

package body Ocarina.Instances.REAL_Checker.Queries.Access_Predicates is
   use Ocarina.ME_AADL.AADL_Instances.Nodes;

   ---------------------------
   -- Is_Accessed_Predicate --
   ---------------------------

   function Is_Accessed_Predicate
     (E      : Node_Id;
      D      : Node_Id;
      Option : Predicates_Search_Options := PSO_Direct)
     return Boolean
   is
      pragma Unreferenced (Option);

      P : Node_Id;
      N : Node_Id;
      K : Node_Id;
   begin
      if Kind (D) /= K_Connection_Instance  and then
        (Kind (D) /= K_Component_Instance or else
         Kind (E) /= K_Subcomponent_Access_Instance) then
         return False;
      end if;

      if Kind (D) = K_Connection_Instance then
         P := Destination (D);
         if Corresponding_Instance (Item (First_Node (Path (P)))) = E then
            return True;
         else
            P := Source (D);
            return (Corresponding_Instance
                    (Item (First_Node (Path (P)))) = E);
         end if;
      end if;

      if Features (D) /= No_List then

         P := First_Node (Features (D));

         while Present (P) loop
            N := First_Node (Destinations (P));
            while Present (N) loop
               K := Item (N);

               if Kind (K) = K_Subcomponent_Access_Instance then

                  if Corresponding_Instance (K) = E then
                     return True;
                  end if;

               end if;

               N := Next_Node (N);
            end loop;

            P := Next_Node (P);
         end loop;

      end if;

      return False;
   end Is_Accessed_Predicate;

end Ocarina.Instances.REAL_Checker.Queries.Access_Predicates;
