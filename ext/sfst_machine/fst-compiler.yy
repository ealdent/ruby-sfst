%{
/*******************************************************************/
/*                                                                 */
/*  FILE     fst-compiler.yy                                       */
/*  MODULE   fst-compiler                                          */
/*  PROGRAM  SFST                                                  */
/*  AUTHOR   Helmut Schmid, IMS, University of Stuttgart           */
/*                                                                 */
/*******************************************************************/

#include <stdio.h>

#include "make-compact.h"
#include "interface.h"

using std::cerr;

extern int  yylineno;
extern char *yytext;

void yyerror(char *text);
void warn(char *text);
void warn2(char *text, char *text2);
int yylex( void );
int yyparse( void );

static int Switch=0;
Transducer *Result;
%}

%union {
  int        number;
  Twol_Type  type;
  Repl_Type  rtype;
  char       *name;
  char       *value;
  unsigned char uchar;
  unsigned int  longchar;
  Character  character;
  Transducer  *expression;
  Range      *range;
  Ranges     *ranges;
  Contexts   *contexts;
}

%token <number> NEWLINE ALPHA COMPOSE PRINT POS INSERT SWITCH
%token <type>   ARROW
%token <rtype>  REPLACE
%token <name>   SYMBOL VAR SVAR RVAR RSVAR
%token <value>  STRING STRING2 UTF8CHAR
%token <uchar>  CHARACTER

%type  <uchar>      SCHAR
%type  <longchar>   LCHAR
%type  <character>  CODE
%type  <expression> RE
%type  <range>      RANGE VALUE VALUES
%type  <ranges>     RANGES
%type  <contexts>   CONTEXT CONTEXT2 CONTEXTS CONTEXTS2

%left PRINT INSERT
%left ARROW REPLACE
%left COMPOSE
%left '|'
%left '-'
%left '&'
%left SEQ
%left '!' '^' '_'
%left '*' '+'
%%

ALL:        ASSIGNMENTS RE NEWLINES { Result=result($2, Switch); }
          ;

ASSIGNMENTS: ASSIGNMENTS ASSIGNMENT {}
          | ASSIGNMENTS NEWLINE     {}
          | /* nothing */           {}
          ;

ASSIGNMENT: VAR '=' RE              { if (def_var($1,$3)) warn2("assignment of empty transducer to",$1); }
          | RVAR '=' RE             { if (def_rvar($1,$3)) warn2("assignment of empty transducer to",$1); }
          | SVAR '=' VALUES         { if (def_svar($1,$3)) warn2("assignment of empty symbol range to",$1); }
          | RSVAR '=' VALUES        { if (def_svar($1,$3)) warn2("assignment of empty symbol range to",$1); }
          | RE PRINT STRING         { write_to_file($1, $3); }
          | ALPHA RE                { def_alphabet($2); }
          ;

RE:         RE ARROW CONTEXTS2      { $$ = restriction($1,$2,$3,0); }
	  | RE '^' ARROW CONTEXTS2  { $$ = restriction($1,$3,$4,1); }
	  | RE '_' ARROW CONTEXTS2  { $$ = restriction($1,$3,$4,-1); }
          | RE REPLACE CONTEXT2     { $$ = replace_in_context(minimise(explode($1)),$2,$3,false); }
          | RE REPLACE '?' CONTEXT2 { $$ = replace_in_context(minimise(explode($1)),$2,$4,true);}
          | RE REPLACE '(' ')'      { $$ = replace(minimise(explode($1)), $2, false); }
          | RE REPLACE '?' '(' ')'  { $$ = replace(minimise(explode($1)), $2, true); }
          | RE RANGE ARROW RANGE RE { $$ = make_rule($1,$2,$3,$4,$5); }
          | RE RANGE ARROW RANGE    { $$ = make_rule($1,$2,$3,$4,NULL); }
          | RANGE ARROW RANGE RE    { $$ = make_rule(NULL,$1,$2,$3,$4); }
          | RANGE ARROW RANGE       { $$ = make_rule(NULL,$1,$2,$3,NULL); }
          | RE COMPOSE RE    { $$ = composition($1, $3); }
          | '{' RANGES '}' ':' '{' RANGES '}' { $$ = make_mapping($2,$6); }
          | RANGE ':' '{' RANGES '}' { $$ = make_mapping(add_range($1,NULL),$4); }
          | '{' RANGES '}' ':' RANGE { $$ = make_mapping($2,add_range($5,NULL)); }
          | RE INSERT CODE ':' CODE  { $$ = freely_insert($1, $3, $5); }
          | RE INSERT CODE           { $$ = freely_insert($1, $3, $3); }
          | RANGE ':' RANGE  { $$ = new_transducer($1,$3); }
          | RANGE            { $$ = new_transducer($1,$1); }
          | VAR              { $$ = var_value($1); }
          | RVAR             { $$ = rvar_value($1); }
          | RE '*'           { $$ = repetition($1); }
          | RE '+'           { $$ = repetition2($1); }
          | RE '?'           { $$ = optional($1); }
          | RE RE %prec SEQ  { $$ = catenate($1, $2); }
          | '!' RE           { $$ = negation($2); }
          | SWITCH RE        { $$ = switch_levels($2); }
          | '^' RE           { $$ = upper_level($2); }
          | '_' RE           { $$ = lower_level($2); }
          | RE '&' RE        { $$ = conjunction($1, $3); }
          | RE '-' RE        { $$ = subtraction($1, $3); }
          | RE '|' RE        { $$ = disjunction($1, $3); }
          | '(' RE ')'       { $$ = $2; }
          | STRING           { $$ = read_words($1); }
          | STRING2          { $$ = read_transducer($1); }
          ;

RANGES:     RANGE RANGES     { $$ = add_range($1,$2); }
          |                  { $$ = NULL; }
          ;

RANGE:      '[' VALUES ']'   { $$=$2; }
          | '[' '^' VALUES ']' { $$=complement_range($3); }
          | '[' RSVAR ']'    { $$=rsvar_value($2); }
          | '.'              { $$=NULL; }
          | CODE             { $$=add_value($1,NULL); }
          ;

CONTEXTS2:  CONTEXTS               { $$ = $1; }
          | '(' CONTEXTS ')'       { $$ = $2; }
          ;

CONTEXTS:   CONTEXT ',' CONTEXTS   { $$ = add_context($1,$3); }
          | CONTEXT                { $$ = $1; }
          ;

CONTEXT2:   CONTEXT                { $$ = $1; }
          | '(' CONTEXT ')'        { $$ = $2; }
          ;

CONTEXT :   RE POS RE              { $$ = make_context($1, $3); }
          |    POS RE              { $$ = make_context(NULL, $2); }
          | RE POS                 { $$ = make_context($1, NULL); }
          ;

VALUES:     VALUE VALUES           { $$=append_values($1,$2); }
          | VALUE                  { $$ = $1; }
          ;

VALUE:      LCHAR '-' LCHAR	   { $$=add_values($1,$3,NULL); }
          | SVAR                   { $$=svar_value($1); }
          | LCHAR  	           { $$=add_value(character_code($1),NULL); }
          | CODE		   { $$=add_value($1,NULL); }
	  | SCHAR		   { $$=add_value($1,NULL); }
          ;

LCHAR:      CHARACTER	{ $$=$1; }
          | UTF8CHAR	{ $$=utf8toint($1); free($1); }
	  | SCHAR       { $$=$1; }
          ;

CODE:       CHARACTER	{ $$=character_code($1); }
          | UTF8CHAR	{ $$=symbol_code($1); }
          | SYMBOL	{ $$=symbol_code($1); }
          ;

SCHAR:      '.'		{ $$=character_code('.'); }
          | '!'		{ $$=character_code('!'); }
          | '?'		{ $$=character_code('?'); }
          | '{'		{ $$=character_code('{'); }
          | '}'		{ $$=character_code('}'); }
          | ')'		{ $$=character_code(')'); }
          | '('		{ $$=character_code('('); }
          | '&'		{ $$=character_code('&'); }
          | '|'		{ $$=character_code('|'); }
          | '*'		{ $$=character_code('*'); }
          | '+'		{ $$=character_code('+'); }
          | ':'		{ $$=character_code(':'); }
          | ','		{ $$=character_code(','); }
          | '='		{ $$=character_code('='); }
          | '_'		{ $$=character_code('_'); }
          | '^'		{ $$=character_code('^'); }
          | '-'		{ $$=character_code('-'); }
          ;

NEWLINES:   NEWLINE NEWLINES     {}
          | /* nothing */        {}
          ;

%%

extern FILE  *yyin;

/*******************************************************************/
/*                                                                 */
/*  yyerror                                                        */
/*                                                                 */
/*******************************************************************/

void yyerror(char *text)

{
  cerr << "\n" << FileName << ":" << yylineno << ": " << text << " at: ";
  cerr << yytext << "\naborted.\n";
  exit(1);
}
