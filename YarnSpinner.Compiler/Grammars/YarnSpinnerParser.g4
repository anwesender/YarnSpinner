parser grammar YarnSpinnerParser;

options { tokenVocab=YarnSpinnerLexer; }

dialogue
    : (file_hashtag*) node+ 
    ;

// File-global hashtags, which precede all nodes
file_hashtag
    : HASHTAG text=HASHTAG_TEXT
    ;

node
    : (header|when_header|title_header)+ BODY_START  body BODY_END
    ;

title_header:
    HEADER_TITLE HEADER_DELIMITER title=ID NEWLINE
    ;

when_header:
    HEADER_WHEN HEADER_DELIMITER header_expression=header_when_expression NEWLINE
    ;

header 
    // : header_key=ID HEADER_DELIMITER (header_value=REST_OF_LINE|header_expression=header_when_expression NEWLINE)?
    : header_key=ID HEADER_DELIMITER (header_value=REST_OF_LINE)?
    ;

header_when_expression
    : expression 
    | (always=EXPRESSION_WHEN_ALWAYS) 
    | once=COMMAND_ONCE (value)? (COMMAND_IF expression)?
    ;

body
    : statement*
    ;

statement
    : line_statement
    | if_statement
    | set_statement
    | shortcut_option_statement
    | call_statement
    | command_statement
    | declare_statement
    | enum_statement
    | jump_statement
    | return_statement
    | result_statement
    | line_group_statement
    | once_statement
    | func_statement
    | invoke_statement
    | INDENT statement* DEDENT
    ;

line_statement
    :
        line_formatted_text // text, interspersed with expressions
        line_condition? // a line condition
        hashtag*  // any number of hashtags
        NEWLINE
    ;

line_formatted_text
    : ( TEXT+ // one or more chunks of text to show to the player
      | EXPRESSION_START expression EXPRESSION_END // an expression to evaluate
      )+ 
    ;

hashtag
    : HASHTAG text=HASHTAG_TEXT
    ;

line_condition
    : COMMAND_START COMMAND_IF expression COMMAND_END #lineCondition
    | COMMAND_START COMMAND_ONCE (value)? (COMMAND_IF expression)? COMMAND_END #lineOnceCondition
    ;

expression
    : '(' expression ')' #expParens
    | <assoc=right>op='-' expression #expNegative
    | <assoc=right>op=OPERATOR_LOGICAL_NOT expression #expNot
    | expression op=('*' | '/' | '%') expression #expMultDivMod
    | expression op=('+' | '-') expression #expAddSub
    | expression op=(OPERATOR_LOGICAL_LESS_THAN_EQUALS | OPERATOR_LOGICAL_GREATER_THAN_EQUALS | OPERATOR_LOGICAL_LESS | OPERATOR_LOGICAL_GREATER ) expression #expComparison
    | expression op=(OPERATOR_LOGICAL_EQUALS | OPERATOR_LOGICAL_NOT_EQUALS) expression #expEquality
    | expression op=(OPERATOR_LOGICAL_AND | OPERATOR_LOGICAL_OR | OPERATOR_LOGICAL_XOR) expression #expAndOrXor
    | value #expValue
    ;

value
    : NUMBER         #valueNumber
    | KEYWORD_TRUE   #valueTrue
    | KEYWORD_FALSE  #valueFalse
    | variable       #valueVar
    | temp_variable  #valueTempVar
    | STRING #valueString
    | INDIRECT_START expression EXPRESSION_END #valueIndirect  // indirect variable read: {expr}
    | function_call       #valueFunc
    | typeMemberReference #valueTypeMemberReference

    ;
variable
    : VAR_ID
    ;

temp_variable
    : TEMP_VAR_ID
    ;

function_call 
    : FUNC_ID '(' expression? (COMMA expression)* ')' ;

typeMemberReference
    : (typeName=FUNC_ID)? '.' memberName=FUNC_ID
    ;

if_statement
    : if_clause                                 // <<if foo>> statements...
      else_if_clause*                           // <<elseif bar>> statements.. (can have zero or more of these)
      else_clause?                              // <<else>> statements (optional)
      COMMAND_START COMMAND_ENDIF COMMAND_END	// <<endif>>
    ;

if_clause
    : COMMAND_START COMMAND_IF expression COMMAND_END statement*
    ;

else_if_clause
    : COMMAND_START COMMAND_ELSEIF expression COMMAND_END statement*
    ;

else_clause
    : COMMAND_START COMMAND_ELSE COMMAND_END statement*
    ;

set_statement
    : COMMAND_START COMMAND_SET variable op=(OPERATOR_ASSIGNMENT | '*=' | '/=' | '%=' | '+=' | '-=') expression COMMAND_END
    | COMMAND_START COMMAND_SET temp_variable op=(OPERATOR_ASSIGNMENT | '*=' | '/=' | '%=' | '+=' | '-=') expression COMMAND_END
    | COMMAND_START COMMAND_SET INDIRECT_START varNameExpr=expression EXPRESSION_END OPERATOR_ASSIGNMENT valueExpr=expression COMMAND_END
    ;

call_statement
    : COMMAND_START COMMAND_CALL function_call COMMAND_END
    ;

command_statement
    : COMMAND_START command_formatted_text COMMAND_END (hashtag*)
    ;

command_formatted_text
	: (COMMAND_TEXT|EXPRESSION_START expression EXPRESSION_END)+
	;

shortcut_option_statement
    : shortcut_option* (shortcut_option BLANK_LINE_FOLLOWING_OPTION?)
    ;

shortcut_option
    : '->' line_statement (INDENT statement* DEDENT)?
    ;

line_group_statement
    : line_group_item* (line_group_item BLANK_LINE_FOLLOWING_OPTION?)
    ;

line_group_item
    : '=>' line_statement (INDENT statement* DEDENT)?
    ;

declare_statement
    : COMMAND_START COMMAND_DECLARE variable OPERATOR_ASSIGNMENT expression ('as' type=FUNC_ID)? COMMAND_END
    | COMMAND_START COMMAND_DECLARE temp_variable OPERATOR_ASSIGNMENT expression ('as' type=FUNC_ID)? COMMAND_END
    ;

enum_statement
    : COMMAND_START COMMAND_ENUM name=ID COMMAND_END enum_case_statement+ COMMAND_START COMMAND_ENDENUM COMMAND_END
    ;

enum_case_statement
    : INDENT? COMMAND_START COMMAND_CASE name=FUNC_ID (OPERATOR_ASSIGNMENT rawValue=value)? COMMAND_END DEDENT?
    ;

jump_statement
    : COMMAND_START COMMAND_JUMP destination=ID COMMAND_END #jumpToNodeName
    | COMMAND_START COMMAND_JUMP EXPRESSION_START expression EXPRESSION_END COMMAND_END #jumpToExpression
    | COMMAND_START COMMAND_DETOUR destination=ID COMMAND_END #detourToNodeName
    | COMMAND_START COMMAND_DETOUR EXPRESSION_START expression EXPRESSION_END COMMAND_END #detourToExpression
    | COMMAND_START COMMAND_NEXT destination=ID COMMAND_END #nextToNodeName
    | COMMAND_START COMMAND_NEXT EXPRESSION_START expression EXPRESSION_END COMMAND_END #nextToExpression
    ;

return_statement
    : COMMAND_START COMMAND_RETURN COMMAND_END
    ;

// Return a value from a Yarn function
// Usage: <<result expression>>
// This pushes the expression result onto the stack and returns from the function
result_statement
    : COMMAND_START COMMAND_RESULT expression COMMAND_END
    ;

once_statement
    : once_primary_clause 
      once_alternate_clause? 
      COMMAND_START COMMAND_ENDONCE COMMAND_END
    ;
    
once_primary_clause
    : COMMAND_START COMMAND_ONCE (value)? (COMMAND_IF expression)? COMMAND_END statement*
    ;

once_alternate_clause
    : COMMAND_START COMMAND_ELSE COMMAND_END statement*
    ;

// User-defined Yarn functions with temporary parameters
// Usage: <<func myFunction(~param1, ~param2)>>
func_statement
    : func_header
      statement*
      COMMAND_START COMMAND_ENDFUNC COMMAND_END
    ;

func_header
    : COMMAND_START COMMAND_FUNC name=FUNC_ID LPAREN func_params? RPAREN COMMAND_END
    ;

func_params
    : func_param (COMMA func_param)*
    ;

func_param
    : TEMP_VAR_ID (OPERATOR_ASSIGNMENT expression)?   // ~paramName with optional default value
    ;

// Invoke a Yarn function with arguments and optional return value
// Command-style syntax (no parentheses or commas):
// Usage: <<invoke myFunction arg1 arg2>>
// Usage: <<invoke ~result = myFunction arg1 arg2>>
// Usage: <<invoke $result = myFunction arg1 arg2>>
invoke_statement
    : COMMAND_START COMMAND_INVOKE temp_variable OPERATOR_ASSIGNMENT FUNC_ID invoke_args? COMMAND_END #invokeWithTempReturn
    | COMMAND_START COMMAND_INVOKE variable OPERATOR_ASSIGNMENT FUNC_ID invoke_args? COMMAND_END #invokeWithPersistentReturn
    | COMMAND_START COMMAND_INVOKE FUNC_ID invoke_args? COMMAND_END #invokeNoReturn
    ;

// Arguments to invoke are space-separated expressions
invoke_args
    : expression+
    ;

structured_command
    : command_id=FUNC_ID structured_command_value*
    ;

structured_command_value
    : expression
    // parse commands as a sequence of IDs, expressions, and (for compatibility)
    // braced expressions

    // | '{' expression '}'
    | FUNC_ID
    ;
