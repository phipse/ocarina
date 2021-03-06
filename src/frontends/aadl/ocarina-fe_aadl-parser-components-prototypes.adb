------------------------------------------------------------------------------
--                                                                          --
--                           OCARINA COMPONENTS                             --
--                                                                          --
--              OCARINA.FE_AADL.PARSER.COMPONENTS.PROTOTYPES                --
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

--  This package gathers all the functions that are related to prototype
--  parsing.

with Ocarina.ME_AADL.AADL_Tree.Nodes;
with Locations;

with Ocarina.ME_AADL.AADL_Tree.Nutils;

with Ocarina.ME_AADL.Tokens;
with Ocarina.FE_AADL.Lexer;
with Ocarina.FE_AADL.Parser.Identifiers;
with Ocarina.FE_AADL.Parser.Components;

with Ocarina.Builder.AADL.Components;
with Ocarina.Builder.AADL.Components.Prototypes;

package body Ocarina.FE_AADL.Parser.Components.Prototypes is

   -----------------------------------------
   -- P_Prototype_Or_Prototype_Refinement --
   -----------------------------------------

   --  AADL_V2

   --  prototype ::= defining_prototype_identifier : component_category
   --   [ unique_component_classifier_reference ]

   --  prototype_refinement ::= defining_prototype_identifier : refined to
   --      component_category [ unique_component_classifier_reference ] ;

   function P_Prototype_Or_Prototype_Refinement
     (Container : Types.Node_Id;
      Refinable : Boolean)
     return Node_Id
   is
      use Locations;
      use Ocarina.ME_AADL.AADL_Tree.Nodes;
      use Ocarina.ME_AADL.Tokens;
      use Lexer;
      use Parser.Identifiers;
      use Ocarina.Builder.AADL.Components.Prototypes;

      Loc            : Location;
      Identifier     : Node_Id;
      Prototype      : Node_Id;
      Classifier_Ref : Node_Id;
      Category       : Component_Category;
      Code           : Parsing_Code;
      Is_Refinement  : Boolean;
      OK             : Boolean;
   begin
      P_Identifier_Refined_To
        (Refinable_To_RT (Refinable),
         False,
         PC_Prototype,
         PC_Prototype_Refinement,
         T_Semicolon,
         Identifier,
         Is_Refinement,
         OK);

      if not OK then
         return No_Node;
      end if;

      if Is_Refinement then
         Code := PC_Prototype;
      else
         Code := PC_Prototype_Refinement;
      end if;

      Scan_Token;
      Category := P_Component_Category;

      if Category = CC_Unknown then
         Skip_Tokens (T_Semicolon);
         return No_Node;
      end if;

      Save_Lexer (Loc);
      Scan_Token;

      if Token = T_Identifier then
         Restore_Lexer (Loc);
         Classifier_Ref := P_Entity_Reference (Code);

         if No (Classifier_Ref) then
            Skip_Tokens (T_Semicolon);
            return No_Node;
         end if;
      else
         Classifier_Ref := No_Node;
         Restore_Lexer (Loc);
      end if;

      Prototype := Add_New_Prototype
        (Loc            => Ocarina.ME_AADL.AADL_Tree.Nodes.Loc (Identifier),
         Name           => Identifier,
         Container      => Container,
         Classifier_Ref => Classifier_Ref,
         Category       => Category,
         Is_Refinement  => Is_Refinement);

      Save_Lexer (Loc);
      Scan_Token;
      if Token /= T_Semicolon
        or else Prototype = No_Node
      then
         DPE (Code, T_Semicolon);
         Restore_Lexer (Loc);
         return No_Node;
      end if;

      return Prototype;
   end P_Prototype_Or_Prototype_Refinement;

   --------------------------
   -- P_Prototype_Bindings --
   --------------------------

   --  AADL_V2

   --  prototype_bindings ::=
   --   ( prototype_binding ( , prototype_ binding )* )

   function P_Prototype_Bindings (Container : Types.Node_Id) return Boolean
   is
      use Locations;
      use Ocarina.ME_AADL.AADL_Tree.Nodes;
      use Ocarina.ME_AADL.AADL_Tree.Nutils;
      use Ocarina.ME_AADL.Tokens;
      use Lexer;

      Loc                : Location;
      Prototype_Bindings : List_Id;
      Success            : Boolean   := True;
   begin
      Save_Lexer (Loc);

      if Token /= T_Left_Parenthesis then
         DPE (PC_Prototype_Bindings, T_Left_Parenthesis);
         Skip_Tokens (T_Semicolon);
         Success := False;
      end if;

      Prototype_Bindings := P_Items_List (P_Prototype_Binding'Access,
                                Container,
                                T_Comma,
                                T_Right_Parenthesis,
                                PC_Prototype_Bindings,
                                False);
      if Is_Empty (Prototype_Bindings) then
         DPE (PC_Prototype_Bindings, EMC_List_Is_Empty);
         Skip_Tokens (T_Semicolon);
         return Success;
      else
         Set_Prototype_Bindings (Container, Prototype_Bindings);
         Success := True;
      end if;

      return Success;

   end P_Prototype_Bindings;

   -------------------------
   -- P_Prototype_Binding --
   -------------------------

   --  AADL_V2

   --  prototype_binding ::=
   --   prototype_identifier => component_category
   --    ( unique_component_classifier_reference |prototype_identifier )

   function P_Prototype_Binding (Container : Types.Node_Id) return Node_Id
   is
      use Locations;
      use Ocarina.ME_AADL.Tokens;
      use Lexer;
      use Ocarina.ME_AADL.AADL_Tree.Nodes;
      use Ocarina.FE_AADL.Parser.Identifiers;
      use Ocarina.Builder.AADL.Components.Prototypes;

      Start_Loc         : Location;
      Loc               : Location;
      Identifier        : Node_Id;
      Classifier_Ref    : Node_Id;
      Prototype_Binding : Node_Id;
      Category          : Component_Category;
   begin
      Save_Lexer (Start_Loc);

      Identifier := P_Identifier (Container);
      if Identifier = No_Node then
         DPE (PC_Prototype_Binding);
         Skip_Tokens (T_Semicolon);
         return No_Node;
      end if;

      Save_Lexer (Loc);
      Scan_Token;

      if Token /= T_Association then
         Skip_Tokens (T_Semicolon);
         return No_Node;
      end if;

      Save_Lexer (Loc);
      Scan_Token;

      Category := P_Component_Category;
      if Category = CC_Unknown then
         Skip_Tokens (T_Semicolon);
         return No_Node;
      end if;

      Classifier_Ref := P_Entity_Reference (PC_Prototype_Binding);
      if Classifier_Ref = No_Node then
         DPE (PC_Prototype_Binding);
         Skip_Tokens (T_Semicolon);
         return No_Node;
      end if;

      Prototype_Binding := Add_New_Prototype_Binding (Start_Loc,
                                                      Identifier,
                                                      Container,
                                                      Classifier_Ref,
                                                      Category);

      if Prototype_Binding = No_Node then
         DPE (PC_Prototype_Binding);
         Skip_Tokens (T_Semicolon);
         return No_Node;
      end if;

      return Prototype_Binding;
   end P_Prototype_Binding;

end Ocarina.FE_AADL.Parser.Components.Prototypes;
