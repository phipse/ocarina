------------------------------------------------------------------------------
--                                                                          --
--                           OCARINA COMPONENTS                             --
--                                                                          --
--       O C A R I N A . B A C K E N D S . P O K _ C . R U N T I M E        --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--    Copyright (C) 2008-2009 Telecom ParisTech, 2010-2012 ESA & ISAE.      --
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

with GNAT.OS_Lib; use GNAT.OS_Lib;
with GNAT.Case_Util;

with Utils; use Utils;

with Charset; use Charset;
with Namet;   use Namet;

with Ocarina.Backends.C_Tree.Nodes;
with Ocarina.Backends.C_Tree.Nutils;

package body Ocarina.Backends.POK_C.Runtime is

   use Ocarina.Backends.C_Tree.Nodes;
   use Ocarina.Backends.C_Tree.Nutils;

   Initialized : Boolean := False;

   Current_Kernel_Unit : Node_Id;

   RED : array (RE_Id) of Node_Id := (RE_Id'Range => No_Node);
   RHD : array (RH_Id) of Node_Id := (RH_Id'Range => No_Node);

   --  Arrays of run-time entity and unit designators

   type Casing_Rule is record
      Size : Natural;
      From : String_Access;
      Into : String_Access;
   end record;

   Rules : array (1 .. 64) of Casing_Rule;
   Rules_Last : Natural := 0;

   procedure Apply_Casing_Rules (S : in out String);
   --  Apply the registered casing rules on the string S

   procedure Register_Casing_Rule (S : String);
   --  Register a custom casing rule

   ------------------------
   -- Apply_Casing_Rules --
   ------------------------

   procedure Apply_Casing_Rules (S : in out String) is
      New_Word : Boolean := True;
      Length   : Natural := S'Length;
      S1       : constant String := To_Lower (S);
   begin
      GNAT.Case_Util.To_Mixed (S);

      for I in S'Range loop
         if New_Word then
            New_Word := False;
            for J in 1 .. Rules_Last loop
               if Rules (J).Size <= Length
                 and then S1 (I .. I + Rules (J).Size - 1) = Rules (J).From.all
               then
                  S (I .. I + Rules (J).Size - 1) := Rules (J).Into.all;
               end if;
            end loop;
         end if;
         if S (I) = '_' then
            New_Word := True;
            for J in 1 .. Rules_Last loop
               if Rules (J).Size <= Length
                 and then S1 (I .. I + Rules (J).Size - 1) = Rules (J).From.all
               then
                  S (I .. I + Rules (J).Size - 1) := Rules (J).Into.all;
               end if;
            end loop;
         end if;
         Length := Length - 1;
      end loop;
   end Apply_Casing_Rules;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
      Name       : Name_Id;
      N          : Node_Id;
      Is_Local   : Boolean;
   begin
      --  Initialize the runtime only once

      if Initialized then
         return;
      end if;

      Initialized := True;

      if POK_Flavor = ARINC653 then
         RH_Service_Table (RH_Assert)     := RHS_Null;
         RH_Service_Table (RH_Thread)     := RHS_Core;
         RH_Service_Table (RH_Error)      := RHS_ARINC653;
         RH_Service_Table (RH_Blackboard) := RHS_ARINC653;
         RH_Service_Table (RH_Buffer)     := RHS_ARINC653;
         RH_Service_Table (RH_Queueing)   := RHS_ARINC653;
         RH_Service_Table (RH_Semaphore)  := RHS_ARINC653;
         RH_Service_Table (RH_Event)      := RHS_ARINC653;
         RH_Service_Table (RH_Sampling)   := RHS_ARINC653;
         RH_Service_Table (RH_Types)      := RHS_ARINC653;
         RH_Service_Table (RH_Time)       := RHS_ARINC653;
         RH_Service_Table (RH_Partition)  := RHS_ARINC653;
      end if;

      --  When we use the ARINC653 API, we change the include/
      --  directory for headers files. So, we change the following
      --  table that indicates the directory of each include file.

      Register_Casing_Rule ("AADL");
      Register_Casing_Rule ("char_array");
      Register_Casing_Rule ("nul");

      --  Apply casing rule for POK functions.
      --  All types are in lower case.

      for E in PRF_Id loop
         Set_Str_To_Name_Buffer (RE_Id'Image (E));
         Set_Str_To_Name_Buffer (Name_Buffer (4 .. Name_Len));

         Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));

         while Name_Buffer (Name_Len) = '_'
         loop
            Name_Len := Name_Len - 1;
         end loop;

         Name := Name_Find;

         Name := Utils.To_Lower (Name);
         RED (E) := New_Node (K_Defining_Identifier);
         Set_Name
           (RED (E), Name);
      end loop;

      --  Apply casing rule for ARINC653 functions.
      --  All functions are in upper case.

      for E in ARF_Id loop
         Set_Str_To_Name_Buffer (RE_Id'Image (E));
         Set_Str_To_Name_Buffer (Name_Buffer (4 .. Name_Len));

         Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));

         while Name_Buffer (Name_Len) = '_'
         loop
            Name_Len := Name_Len - 1;
         end loop;

         Name := Name_Find;

         Name := Utils.To_Upper (Name);
         RED (E) := New_Node (K_Defining_Identifier);
         Set_Name
           (RED (E), Name);
      end loop;

      --  Apply casing rule for POK types.
      --  All types are in lower case.

      for E in PRT_Id loop
         Set_Str_To_Name_Buffer (RE_Id'Image (E));
         Set_Str_To_Name_Buffer (Name_Buffer (4 .. Name_Len));

         Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));

         while Name_Buffer (Name_Len) = '_'
         loop
            Name_Len := Name_Len - 1;
         end loop;

         Name := Name_Find;

         Name := Utils.To_Lower (Name);
         RED (E) := New_Node (K_Defining_Identifier);
         Set_Name
           (RED (E), Name);
      end loop;

      --  Apply casing rule for ARINC653 types.
      --  All types are in upper case.

      for E in ART_Id loop
         Set_Str_To_Name_Buffer (RE_Id'Image (E));
         Set_Str_To_Name_Buffer (Name_Buffer (4 .. Name_Len));

         Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));

         while Name_Buffer (Name_Len) = '_'
         loop
            Name_Len := Name_Len - 1;
         end loop;

         Name := Name_Find;

         Name := Utils.To_Upper (Name);
         RED (E) := New_Node (K_Defining_Identifier);
         Set_Name
           (RED (E), Name);
      end loop;

      --  Apply casing rule for headers, there is no difference
      --  between POK and ARINC653 headers casing rules, so, we
      --  use the same.

      for E in RH_Id loop
         Set_Str_To_Name_Buffer (RH_Id'Image (E));
         Set_Str_To_Name_Buffer (Name_Buffer (4 .. Name_Len));
         Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));

         while Name_Buffer (Name_Len) = '_'
         loop
            Name_Len := Name_Len - 1;
         end loop;

         if RH_Service_Table (E) = RHS_Generated then
            Is_Local := True;
         elsif RH_Service_Table (E) /= RHS_Null then
            Is_Local := False;
            Name := Name_Find;
            Set_Str_To_Name_Buffer (RHS_Id'Image (RH_Service_Table (E)));
            Set_Str_To_Name_Buffer (Name_Buffer (5 .. Name_Len));
            Add_Str_To_Name_Buffer ("/");
            Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));
            Get_Name_String_And_Append (Name);
         else
            Is_Local := False;
         end if;

         Name := Name_Find;

         Name := Utils.To_Lower (Name);

         N := New_Node (K_Defining_Identifier);
         Set_Name (N, Name);
         RHD (E) := Make_Include_Clause (N, Is_Local);
      end loop;

      --  Apply casing rule for constants, there is no difference
      --  between POK and ARINC653 constants casing rules, so, we
      --  use the same.

      for E in RC_Id loop
         Set_Str_To_Name_Buffer (RC_Id'Image (E));
         Set_Str_To_Name_Buffer (Name_Buffer (4 .. Name_Len));
         Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));

         while Name_Buffer (Name_Len) in '0' .. '9'
           or else Name_Buffer (Name_Len) = '_'
         loop
            Name_Len := Name_Len - 1;
         end loop;

         Name := Name_Find;

         Name := To_Upper (Name);
         RED (E) := New_Node (K_Defining_Identifier);
         Set_Name
           (RED (E), Name);
      end loop;

      --  Apply casing rule for variables, there is no difference
      --  between POK and ARINC653 variables casing rules, so, we
      --  use the same.

      for E in RV_Id loop
         Set_Str_To_Name_Buffer (RV_Id'Image (E));
         Set_Str_To_Name_Buffer (Name_Buffer (4 .. Name_Len));
         Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));

         while Name_Buffer (Name_Len) in '0' .. '9'
           or else Name_Buffer (Name_Len) = '_'
         loop
            Name_Len := Name_Len - 1;
         end loop;

         Name := Name_Find;

         Name := To_Lower (Name);
         RED (E) := New_Node (K_Defining_Identifier);
         Set_Name
           (RED (E), Name);
      end loop;

      --  Apply casing rule for members. The difference
      --  between POK and ARINC653 is made inside the loop.

      for E in MR_Id loop
         Set_Str_To_Name_Buffer (RC_Id'Image (E));
         Set_Str_To_Name_Buffer (Name_Buffer (4 .. Name_Len));
         Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));

         while Name_Buffer (Name_Len) in '0' .. '9'
           or else Name_Buffer (Name_Len) = '_'
         loop
            Name_Len := Name_Len - 1;
         end loop;

         Name := Name_Find;

         --  If we use the ARINC653 backend flavor, the
         --  members are in upper case. Otherwise, we use
         --  lower case.

         if POK_Flavor = ARINC653 then
            Name := To_Upper (Name);
         else
            Name := To_Lower (Name);
         end if;
         RED (E) := New_Node (K_Defining_Identifier);
         Set_Name
           (RED (E), Name);
      end loop;

   end Initialize;

   -----------
   -- Reset --
   -----------

   procedure Reset is
   begin
      RED := (RE_Id'Range => No_Node);
      RHD := (RH_Id'Range => No_Node);
      Rules_Last := 0;

      Initialized := False;
   end Reset;

   --------
   -- RE --
   --------

   function RE (Id : RE_Id) return Node_Id is
   begin
      if RE_Header_Table (Id) /= RH_Null then
         Add_Include (RH (RE_Header_Table (Id)));
      end if;

      return Copy_Node (RED (Id));
   end RE;

   --------
   -- RF --
   --------

   function RF (Id : RF_Id) return Node_Id is
      N : Node_Id;
      R : RE_Id;
   begin
      N := RE (Id);
      R := RF_Define_Table (Id);
      if R /= RE_Null then
         Add_Define_Deployment (RE (R));
      end if;

      --  Add functionnality in the kernel
      --  according to model needs.
      --  WiP functionnality at this time, needs to describe
      --  each function needs.
      if Id = RE_Pok_Blackboard_Read then
         Push_Entity (Entity (Current_Kernel_Unit));
         Push_Entity (Current_Kernel_Unit);

         Add_Define_Deployment (RE (RE_Pok_Needs_Gettick));

         Pop_Entity;
         Pop_Entity;
      end if;

      return N;
   end RF;

   --------
   -- RH --
   --------

   function RH (Id : RH_Id) return Node_Id is
   begin
      return Copy_Node (RHD (Id));
   end RH;

   --------------------------
   -- Register_Casing_Rule --
   --------------------------

   procedure Register_Casing_Rule (S : String) is
   begin
      Rules_Last := Rules_Last + 1;
      Rules (Rules_Last).Size := S'Length;
      Rules (Rules_Last).Into := new String'(S);
      Rules (Rules_Last).From := new String'(S);
      To_Lower (Rules (Rules_Last).From.all);
   end Register_Casing_Rule;

   --------------------------
   -- Update_Headers_Names --
   --------------------------

   procedure Update_Headers_Names is
      Name     : Name_Id;
   begin
      for E in RH_Id loop
         Set_Str_To_Name_Buffer (RH_Id'Image (E));
         Set_Str_To_Name_Buffer (Name_Buffer (4 .. Name_Len));
         Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));

         while Name_Buffer (Name_Len) = '_'
         loop
            Name_Len := Name_Len - 1;
         end loop;

         if RH_Service_Table (E) /= RHS_Generated
            and then RH_Service_Table (E) /= RHS_Null then
            Name := Name_Find;
            Set_Str_To_Name_Buffer (RHS_Id'Image (RH_Service_Table (E)));
            Set_Str_To_Name_Buffer (Name_Buffer (5 .. Name_Len));
            Add_Str_To_Name_Buffer ("/");
            Apply_Casing_Rules (Name_Buffer (1 .. Name_Len));
            Get_Name_String_And_Append (Name);
         end if;

         Name := Name_Find;

         Name := Utils.To_Lower (Name);

         Set_Name (Header_Name (RHD (E)), Name);
      end loop;
   end Update_Headers_Names;

   -----------------
   -- Normal_Mode --
   -----------------

   procedure Normal_Mode is
   begin
      if POK_Flavor = ARINC653 then
         ARINC653_Mode;
      else
         POK_Mode;
      end if;
   end Normal_Mode;

   --------------
   -- POK_Mode --
   --------------

   procedure POK_Mode is
   begin
      RH_Service_Table (RH_Assert)     := RHS_Null;
      RH_Service_Table (RH_Thread)     := RHS_Core;
      RH_Service_Table (RH_Blackboard) := RHS_Middleware;
      RH_Service_Table (RH_Buffer)     := RHS_Middleware;
      RH_Service_Table (RH_Queueing)   := RHS_Middleware;
      RH_Service_Table (RH_Semaphore)  := RHS_Core;
      RH_Service_Table (RH_Event)      := RHS_Core;
      RH_Service_Table (RH_Sampling)   := RHS_Middleware;
      RH_Service_Table (RH_Types)      := RHS_Null;
      RH_Service_Table (RH_Time)       := RHS_Core;
      RH_Service_Table (RH_Partition)  := RHS_Core;

      Update_Headers_Names;
   end POK_Mode;

   -------------------
   -- ARINC653_Mode --
   -------------------

   procedure ARINC653_Mode is
   begin
      RH_Service_Table (RH_Assert)     := RHS_Null;
      RH_Service_Table (RH_Thread)     := RHS_Core;
      RH_Service_Table (RH_Blackboard) := RHS_ARINC653;
      RH_Service_Table (RH_Buffer)     := RHS_ARINC653;
      RH_Service_Table (RH_Queueing)   := RHS_ARINC653;
      RH_Service_Table (RH_Semaphore)  := RHS_ARINC653;
      RH_Service_Table (RH_Event)      := RHS_ARINC653;
      RH_Service_Table (RH_Sampling)   := RHS_ARINC653;
      RH_Service_Table (RH_Types)      := RHS_ARINC653;
      RH_Service_Table (RH_Time)       := RHS_ARINC653;
      RH_Service_Table (RH_Partition)  := RHS_ARINC653;

      Update_Headers_Names;
   end ARINC653_Mode;

   -----------------
   -- Kernel_Mode --
   -----------------

   procedure Kernel_Mode is
   begin
      --  Same as User_Mode but for the kernel
      RH_Service_Table (RH_Types)      := RHS_Null;
      RH_Service_Table (RH_Partition)  := RHS_Core;
      RH_Service_Table (RH_Error)      := RHS_Core;

      Update_Headers_Names;
   end Kernel_Mode;

   ---------------
   -- User_Mode --
   ---------------

   procedure User_Mode is
   begin
      --  Switch to user mode, change header name
      --  locations, change their containing directories.
      if POK_Flavor = ARINC653 then
         RH_Service_Table (RH_Assert)     := RHS_Null;
         RH_Service_Table (RH_Thread)     := RHS_Core;
         RH_Service_Table (RH_Blackboard) := RHS_ARINC653;
         RH_Service_Table (RH_Error)      := RHS_ARINC653;
         RH_Service_Table (RH_Buffer)     := RHS_ARINC653;
         RH_Service_Table (RH_Queueing)   := RHS_ARINC653;
         RH_Service_Table (RH_Sampling)   := RHS_ARINC653;
         RH_Service_Table (RH_Types)      := RHS_ARINC653;
         RH_Service_Table (RH_Time)       := RHS_ARINC653;
         RH_Service_Table (RH_Partition)  := RHS_ARINC653;
      else
         RH_Service_Table (RH_Assert)     := RHS_Null;
         RH_Service_Table (RH_Thread)     := RHS_Core;
         RH_Service_Table (RH_Blackboard) := RHS_Middleware;
         RH_Service_Table (RH_Buffer)     := RHS_Middleware;
         RH_Service_Table (RH_Queueing)   := RHS_Middleware;
         RH_Service_Table (RH_Sampling)   := RHS_Middleware;
         RH_Service_Table (RH_Types)      := RHS_Null;
         RH_Service_Table (RH_Time)       := RHS_Core;
         RH_Service_Table (RH_Partition)  := RHS_Core;
      end if;

      Update_Headers_Names;
   end User_Mode;

   procedure Register_Kernel_Unit (Unit : Node_Id)
   is
   begin
      Current_Kernel_Unit := Unit;
   end Register_Kernel_Unit;

   function Get_Errcode_OK return Node_Id is
   begin
      if POK_Flavor = ARINC653 then
         return RE (RE_No_Error);
      else
         return RE (RE_Pok_Errno_Ok);
      end if;
   end Get_Errcode_OK;

end Ocarina.Backends.POK_C.Runtime;
