------------------------------------------------------------------------------
--                                                                          --
--                           OCARINA COMPONENTS                             --
--                                                                          --
--       OCARINA.INSTANCES.REAL_CHECKER.QUERIES.CONNECTED_PREDICATES        --
--                                                                          --
--                                 S p e c                                  --
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

--  This package defines a method in order to select instances connected
--  to a user-provided AADL instance

with Ocarina.Instances.REAL_Checker.Queries.Relational_Predicates;
with Types;

package Ocarina.Instances.REAL_Checker.Queries.Connected_Predicates is

   function Is_Connected_Predicate
     (E      : Types.Node_Id;
      D      : Types.Node_Id;
      Option : Predicates_Search_Options := PSO_Direct)
     return Boolean;
   --  Check if the instance E is bound to the instance D
   --  with the relation actual_processor_binding (so D must be
   --  a processor instance).

   package Connected_Query is
      new Ocarina.Instances.REAL_Checker.Queries.Relational_Predicates
     (Is_Connected_Predicate);
   --  Allows to search for all instances connected to a given
   --  component instance in a Result_Set or in the global node
   --  table.

end Ocarina.Instances.REAL_Checker.Queries.Connected_Predicates;
