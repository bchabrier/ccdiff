#!/bin/bash

if [ "$1" = -pass1 ]
then
    PASS=1
fi
if [ "$1" = -pass2 ]
then
    PASS=2
    if [ "$2" = "-only" ]; then HASONLY=1; fi
fi

if [ -z "$PASS" ]
then
    # PASS 1 is used to detect if a test has been marked as "only"
    $0 -pass1
    # PASS 2 actually runs the tests, possibly only the ones marked as "only"
    if [ $? = 14 ]; then $0 -pass2 -only; else $0 -pass2; fi
    exit
fi

RED="$(tput setaf 1)" GRE="$(tput setaf 2)" CYA="$(tput setaf 6)" RST="$(tput sgr0)" 

declare -i INDENT=0
beginSuite() {
    [ "$PASS" != 2 ] && return
    tab; echo "$*"
    INDENT=$(($INDENT + 1))
    if [ "$SKIPNEXT" = 1 ]; then SKIPNEXT=0; SKIP=$INDENT; fi
    if [ "$ONLYNEXT" = 1 ]; then ONLYNEXT=0; ONLY=$INDENT; fi
}

endSuite() {
    [ "$PASS" != 2 ] && return
    if [ "$INDENT" = "$SKIP" ]; then SKIP=""; fi
    if [ "$INDENT" = "$ONLY" ]; then ONLY=""; fi
    INDENT=$(($INDENT - 1))
}

tab()
{
    [ "$INDENT" -gt 0 ] && printf " \e[$(($INDENT * 2 - 1));b"
}

SKIPNEXT=0
skip()
{
    [ $# != 0 ] && echo 'Skip should have no argument!' >&2 && return
    SKIPNEXT=1
}

ONLYNEXT=0
only()
{
    [ $# != 0 ] && echo 'Only should have no argument!' >&2 && return
    [ "$PASS" = 1 ] && exit 14
    ONLYNEXT=1
}

declare -i NB_TESTS=0
declare -i NB_SUCCESS=0
declare -i NB_FAILED=0

[ "$PASS" = 2 ] && trap 'NB_EXECUTED=$(($NB_SUCCESS + $NB_FAILED))
NB_SKIPPED=$(($NB_TESTS - $NB_EXECUTED))
echo
echo -n Executed $NB_EXECUTED/$NB_TESTS tests
[ "$NB_SUCCESS"  -gt 0 ] && echo -n ", ${GRE}$NB_SUCCESS${RST} passed"
[ "$NB_FAILED" -gt 0 ] && echo -n ", ${RED}$NB_FAILED${RST} failed"
[ "$NB_SKIPPED" -gt 0 ] && echo -n ", ${CYA}$NB_SKIPPED${RST} skipped"
if [ "$NB_TESTS" -gt 0 ]
then
    if [ "$NB_EXECUTED" = 0 ]
    then
        pct=100
    else
        pct=$((($NB_SUCCESS * 100)/$NB_EXECUTED))
    fi
    if [ "$pct" -ge 75 ]
    then color="$GRE"
    else if [ "$pct" -ge 35 ] 
        then color=$(tput setaf 3)
        else 
            color="$RED"
        fi 
    fi
    echo ", $color$pct%$RST" successful
fi
echo' 0

os-raw-spaces() {
  od -A n -t dC -v "$@" | tr -d '\n' | cut -c 2- | awk '
    BEGIN {RS=" +"}
    { 
        printf "%02x", $0
        if (32 <= $0 && $0 <= 127) printf "(%c)", $0 
        printf " "
    }
    END { print }
'
}


function test()
{
    [ "$PASS" != 2 ] && return
    if [ "$SKIPNEXT" = 1 ]; then SKIPNEXT=0; SKIP=-1; fi
    if [ "$ONLYNEXT" = 1 ]; then ONLYNEXT=0; ONLY=-1; fi

    local description="$1"
    local command="$2"
    local expected="$3"

    NB_TESTS=$(($NB_TESTS + 1))

    tab; echo -n "Test '$description':... "
    ( 
        ( [ ! -z "$SKIP" ] && [ "$INDENT" -ge "$SKIP" -o "$SKIP" = -1 ] ) || \
        ( [ "$HASONLY" = 1 ] && ! ( [ ! -z "$ONLY" ] && [ "$INDENT" -ge "$ONLY" -o "$ONLY" = -1 ] ) )
    ) && echo "${CYA}Skipped${RST}" && return
    if [ "$SKIP" = -1 ]; then SKIP=""; return; fi
    if [ "$ONLY" = -1 ]; then ONLY=""; fi

    local result="$(eval "$command")"

    if [ "$result" != "$expected" ]
    then
        NB_FAILED=$(($NB_FAILED + 1))

        echo ${RED}KO${RST}
        tab; echo "${RED}Got : >>>${RST}$result${RED}<<<${RST}"
        echo "$result" | os-raw-spaces
        tab; echo "${GRE}expected: >>>${RST}$expected${GRE}<<<${RST}"
        echo "$expected" | os-raw-spaces
        tab; echo "Diffs:"
        ./ccdiff <(echo "$result") <(echo "$expected")
    else
        NB_SUCCESS=$(($NB_SUCCESS + 1))

        echo ${GRE}OK${RST}
    fi
}

function ccdiffstr()
{
    local options=()
    while [[ "$1" == -* ]]
    do
        options+=("$1")
        shift
    done
    ./ccdiff "${options[@]}" <(echo "$1") <(echo "$2")
}


sendmail () {
    echo "sending mail to" $*
    cat
}


beginSuite "Line tests:"
test "3 chars first equal" 'ccdiffstr --html "abc" "abd"' '<font color=red>-</font>ab<font color=red>c</font><BR/>
<font color=green>+</font>ab<font color=green>d</font><BR/>'
test "First char" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "Xcoucou" "coucou"' 'COLOR1-COLORRESETCOLOR1XCOLORRESETcoucou
COLOR2+COLORRESETCOLOR2COLORRESETcoucou'
test "Mixed" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "coucou" "cuicui"' 'COLOR1-COLORRESETcCOLOR1oCOLORRESETuCOLOR1COLORRESETcCOLOR1oCOLORRESETuCOLOR1COLORRESET
COLOR2+COLORRESETcCOLOR2COLORRESETuCOLOR2iCOLORRESETcCOLOR2COLORRESETuCOLOR2iCOLORRESET'
test "first same char" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "abc" "def"' 'COLOR1-abcCOLORRESET
COLOR2+defCOLORRESET'
test "one char diff" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "qdsmflkqjdmlkhqdfmlkqdhfmlqkdshfmlqdsfhmqdfh" "qdsmflkqjdmlkhqdfmlkqdhfmlqkdXhfmlqdsfhmqdfh"' 'COLOR1-COLORRESETqdsmflkqjdmlkhqdfmlkqdhfmlqkdCOLOR1sCOLORRESEThfmlqdsfhmqdfh
COLOR2+COLORRESETqdsmflkqjdmlkhqdfmlkqdhfmlqkdCOLOR2XCOLORRESEThfmlqdsfhmqdfh'
endSuite

beginSuite Block tests:
test "Block diff" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "
1
2
35
4" "
1
2
335
4"' ' 
 1
 2
COLOR1-COLORRESET3COLOR1COLORRESET5
COLOR2+COLORRESET3COLOR23COLORRESET5
 4'
test 'One char diff line' 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "
1
2
qdsmflkqjdmlkhqdfmlkqdhfmlqkdshfmlqdsfhmqdfh
4" "
1
2
qdsmflkqjdmlkhqdfmlkqdhfmlqkdXhfmlqdsfhmqdfh
4"' ' 
 1
 2
COLOR1-COLORRESETqdsmflkqjdmlkhqdfmlkqdhfmlqkdCOLOR1sCOLORRESEThfmlqdsfhmqdfh
COLOR2+COLORRESETqdsmflkqjdmlkhqdfmlkqdhfmlqkdCOLOR2XCOLORRESEThfmlqdsfhmqdfh
 4'
test 'Consecutive char diff lines' 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "
1
222222
qdsmflkqjdmlkhqdfmlkqdhfmlqkdshfmlqdsfhmqdfh
4" "
1
222722
qdsmflkqjdmlkhqdfmlkqdhfmlqkdXhfmlqdsfhmqdfh
4"' ' 
 1
COLOR1-COLORRESET222COLOR12COLORRESET22
COLOR1-COLORRESETqdsmflkqjdmlkhqdfmlkqdhfmlqkdCOLOR1sCOLORRESEThfmlqdsfhmqdfh
COLOR2+COLORRESET222COLOR27COLORRESET22
COLOR2+COLORRESETqdsmflkqjdmlkhqdfmlkqdhfmlqkdCOLOR2XCOLORRESEThfmlqdsfhmqdfh
 4'
test 'One char diff line with insertion' 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "
1
qdsmflkqjdmlkhqdfmlkqdhfmlqkdshfmlqdsfhmqdfh
4" "
1
222722
qdsmflkqjdmlkhqdfmlkqdhfmlqkdXhfmlqdsfhmqdfh
4"' ' 
 1
COLOR1-COLORRESETqdsmflkqjdmlkhqdfmlkqdhfmlqkdCOLOR1sCOLORRESEThfmlqdsfhmqdfh
COLOR2+222722COLORRESET
COLOR2+COLORRESETqdsmflkqjdmlkhqdfmlkqdhfmlqkdCOLOR2XCOLORRESEThfmlqdsfhmqdfh
 4'
test 'Several char diff line with insertion' 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "
1
qdsmflkqjdmlkhqdfqqsdhfmlqkdshfmlqdsfhmqdfh
4
5
pouet
coucou
7
8" "
1
222722
qdsmflkqjdmlkhqdfmlkqdhfmlqkdXhfmlqdsfhmqdfh
4
5
cuicui
tagada
7
8"' ' 
 1
COLOR1-COLORRESETqdsmflkqjdmlkhqdfCOLOR1COLORRESETqCOLOR1qsCOLORRESETdhfmlqkdCOLOR1sCOLORRESEThfmlqdsfhmqdfh
COLOR2+222722COLORRESET
COLOR2+COLORRESETqdsmflkqjdmlkhqdfCOLOR2mlkCOLORRESETqCOLOR2COLORRESETdhfmlqkdCOLOR2XCOLORRESEThfmlqdsfhmqdfh
 4
 5
COLOR1-pouetCOLORRESET
COLOR1-COLORRESETcCOLOR1oCOLORRESETuCOLOR1COLORRESETcCOLOR1oCOLORRESETuCOLOR1COLORRESET
COLOR2+COLORRESETcCOLOR2COLORRESETuCOLOR2iCOLORRESETcCOLOR2COLORRESETuCOLOR2iCOLORRESET
COLOR2+tagadaCOLORRESET
 7
 8'
endSuite

beginSuite 'Display tests:'
    test '--palette=COLOR1:COLOR2:COLORRESET' 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "line" "modifiedline"' 'COLOR1-lineCOLORRESET
COLOR2+modifiedlineCOLORRESET'
    test '--html' 'ccdiffstr --html "line" "modifiedline"' '<font color=red>-line</font><BR/>
<font color=green>+modifiedline</font><BR/>'
    test '--line' 'ccdiffstr --line --palette=COLOR1:COLOR2:COLORRESET "line" "modifiedline"' 'COLOR1-lineCOLORRESET
COLOR2+modifiedlineCOLORRESET'
    test '--char' 'ccdiffstr --char --palette=COLOR1:COLOR2:COLORRESET "line" "modifiedline"' 'COLOR1-COLORRESETCOLOR1COLORRESETline
COLOR2+COLORRESETCOLOR2modifiedCOLORRESETline'
endSuite

beginSuite 'Colordiff tests:'
    beginSuite 'Default:'
        beginSuite 'One line:'
        prev_result=toto
        current_result=toti
        test "1 small line with small diff - should be char colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=auto "$prev_result" "$current_result"' 'COLOR1-COLORRESETtotCOLOR1oCOLORRESET
COLOR2+COLORRESETtotCOLOR2iCOLORRESET'
        prev_result=toto
        current_result=yoyi
        test "1 small line with big diff - should be line colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=auto "$prev_result" "$current_result"' 'COLOR1-totoCOLORRESET
COLOR2+yoyiCOLORRESET'
        prev_result="long long long line"
        current_result="long longXlong line"
        test "1 big line with small diff - should be char colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=auto "$prev_result" "$current_result"' 'COLOR1-COLORRESETlong longCOLOR1 COLORRESETlong line
COLOR2+COLORRESETlong longCOLOR2XCOLORRESETlong line'
        prev_result="long long long line"
        current_result="LONG long LONG LINE"
        test "1 big line with big diff - should be line colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=auto "$prev_result" "$current_result"' 'COLOR1-long long long lineCOLORRESET
COLOR2+LONG long LONG LINECOLORRESET'
        endSuite

        beginSuite 'Block:'
        prev_result="
1
22222
3"
        current_result="
1
22322
3"
        test "Block with small diff - Diff should be char colored" 'ccdiffstr --html --colordiff=auto "$prev_result" "$current_result"' ' <BR/>
 1<BR/>
<font color=red>-</font>22<font color=red>2</font>22<BR/>
<font color=green>+</font>22<font color=green>3</font>22<BR/>
 3<BR/>'
        prev_result="
1
22222
3"
        current_result="
1
55255
3"
        test "Block with big diff - Diff should be line colored" 'ccdiffstr --html --colordiff=auto "$prev_result" "$current_result"' ' <BR/>
 1<BR/>
<font color=red>-22222</font><BR/>
<font color=green>+55255</font><BR/>
 3<BR/>'
        endSuite
    endSuite

    beginSuite 'With --colordiff=char:'
        beginSuite 'One line:'
        prev_result=toto
        current_result=toti
        test "1 small line with small diff - should be char colored" 'ccdiffstr --html --colordiff=char "$prev_result" "$current_result"' '<font color=red>-</font>tot<font color=red>o</font><BR/>
<font color=green>+</font>tot<font color=green>i</font><BR/>'
        prev_result=toto
        current_result=yoyi
        test "1 small line with big diff - should be char colored" 'ccdiffstr --html --colordiff=char "$prev_result" "$current_result"' '<font color=red>-</font><font color=red>tot</font>o<font color=red></font><BR/>
<font color=green>+</font><font color=green>y</font>o<font color=green>yi</font><BR/>'
        prev_result="long long long line"
        current_result="long longXlong line"
        test "1 big line with small diff - should be char colored" 'ccdiffstr --html --colordiff=char "$prev_result" "$current_result"' '<font color=red>-</font>long long<font color=red> </font>long line<BR/>
<font color=green>+</font>long long<font color=green>X</font>long line<BR/>'
        prev_result="long long long line"
        current_result="LONG long LONG LINE"
        test "1 big line with big diff - should be char colored" 'ccdiffstr --html --colordiff=char "$prev_result" "$current_result"' '<font color=red>-</font><font color=red>long</font> long <font color=red>long</font> <font color=red>line</font><BR/>
<font color=green>+</font><font color=green>LONG</font> long <font color=green>LONG</font> <font color=green>LINE</font><BR/>'
        endSuite

        beginSuite 'Block:'
        prev_result="
1
22222
3"
        current_result="
1
22322
3"
        test "Block with small diff - Diff should be char colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=char "$prev_result" "$current_result"' ' 
 1
COLOR1-COLORRESET22COLOR12COLORRESET22
COLOR2+COLORRESET22COLOR23COLORRESET22
 3'
        prev_result="
1
22222
3"
        current_result="
1
55255
3"
        test "Block with big diff - Diff should be char colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=char "$prev_result" "$current_result"' ' 
 1
COLOR1-COLORRESETCOLOR1COLORRESET2COLOR12222COLORRESET
COLOR2+COLORRESETCOLOR255COLORRESET2COLOR255COLORRESET
 3'
        endSuite
    endSuite

    beginSuite 'With --colordiff=line:'
        beginSuite 'One line:'
        prev_result=toto
        current_result=toti
        test "1 small line with small diff - should be line colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=line "$prev_result" "$current_result"' 'COLOR1-totoCOLORRESET
COLOR2+totiCOLORRESET'
        prev_result=toto
        current_result=yoyi
        test "1 small line with big diff - should be line colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=line "$prev_result" "$current_result"' 'COLOR1-totoCOLORRESET
COLOR2+yoyiCOLORRESET'
        prev_result="long long long line"
        current_result="long longXlong line"
        test "1 big line with small diff - should be line colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=line "$prev_result" "$current_result"' 'COLOR1-long long long lineCOLORRESET
COLOR2+long longXlong lineCOLORRESET'
        prev_result="long long long line"
        current_result="LONG long LONG LINE"
        test "1 big line with big diff - should be line colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=line "$prev_result" "$current_result"' 'COLOR1-long long long lineCOLORRESET
COLOR2+LONG long LONG LINECOLORRESET'
        endSuite

        beginSuite 'Block:'
        prev_result="
1
22222
3"
        current_result="
1
22322
3"
        test "Block with small diff - Diff should be line colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=line "$prev_result" "$current_result"' ' 
 1
COLOR1-22222COLORRESET
COLOR2+22322COLORRESET
 3'
        prev_result="
1
22222
3"
        current_result="
1
55255
3"
        test "Block with big diff - Diff should be line colored" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --colordiff=line "$prev_result" "$current_result"' ' 
 1
COLOR1-22222COLORRESET
COLOR2+55255COLORRESET
 3'
        endSuite
    endSuite

    beginSuite "Threshold"
        beginSuite "Threshold default"
            test "Small diff should be char highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "very long line" "a very long line"' 'COLOR1-COLORRESETCOLOR1COLORRESETvery long line
COLOR2+COLORRESETCOLOR2a COLORRESETvery long line'
            test "Medium diff should be char highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "very long line" "long line"' 'COLOR1-COLORRESETCOLOR1very COLORRESETlong line
COLOR2+COLORRESETCOLOR2COLORRESETlong line'
            test "Big diff should be line highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET "very long line" "line"' 'COLOR1-very long lineCOLORRESET
COLOR2+lineCOLORRESET'
        endSuite
        beginSuite "Threshold 0"
            test "Small diff should be char highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --threshold=0 "very long line" "a very long line"' 'COLOR1-COLORRESETCOLOR1COLORRESETvery long line
COLOR2+COLORRESETCOLOR2a COLORRESETvery long line'
            test "Medium diff should be char highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --threshold=0 "very long line" "long line"' 'COLOR1-COLORRESETCOLOR1very COLORRESETlong line
COLOR2+COLORRESETCOLOR2COLORRESETlong line'
            test "Big diff should be char highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --threshold=0 "very long line" "line"' 'COLOR1-COLORRESETCOLOR1very long COLORRESETline
COLOR2+COLORRESETCOLOR2COLORRESETline'
        endSuite
        beginSuite "Threshold 50"
            test "Small diff should be char highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --threshold=50 "very long line" "a very long line"' 'COLOR1-COLORRESETCOLOR1COLORRESETvery long line
COLOR2+COLORRESETCOLOR2a COLORRESETvery long line'
            test "Medium diff should be char highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --threshold=50 "very long line" "long line"' 'COLOR1-COLORRESETCOLOR1very COLORRESETlong line
COLOR2+COLORRESETCOLOR2COLORRESETlong line'
            test "Big diff should be line highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --threshold=50 "very long line" "line"' 'COLOR1-very long lineCOLORRESET
COLOR2+lineCOLORRESET'
        endSuite
        beginSuite "Threshold 100"
            test "Small diff should be line highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --threshold=100 "very long line" "a very long line"' 'COLOR1-very long lineCOLORRESET
COLOR2+a very long lineCOLORRESET'
            test "Medium diff should be line highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --threshold=100 "very long line" "long line"' 'COLOR1-very long lineCOLORRESET
COLOR2+long lineCOLORRESET'
            test "Big diff should be line highlighted" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --threshold=100 "very long line" "line"' 'COLOR1-very long lineCOLORRESET
COLOR2+lineCOLORRESET'
        endSuite
    endSuite
endSuite

beginSuite 'Palette'
    test "Palette with default" 'ccdiffstr --char --palette="RED:GREEN:RESET" "line" "modifiedline"' "RED-RESETREDRESETline
GREEN+RESETGREENmodifiedRESETline"
    test "Palette with --html" 'ccdiffstr --html --char --palette="RED:GREEN:RESET" "line" "modifiedline"' '<font color=red>-</font><font color=red></font>line<BR/>
<font color=green>+</font><font color=green>modified</font>line<BR/>'
endSuite

beginSuite 'Prefixes'
    test "Prefixes" 'ccdiffstr --palette=COLOR1:COLOR2:COLORRESET --prefixes="A:B:C" "1st line
2nd line
3rd line" "1st line
2nd modifiedline
3rd line"' 'C1st line
COLOR1A2nd lineCOLORRESET
COLOR2B2nd modifiedlineCOLORRESET
C3rd line'
endSuite

function updatereadme()
{
    local _balise="$1"
    local _content="$2"
    tmpfile=/tmp/readme.$$
    awk '
        /\[\/\/\]: # \('$_balise' START\)/{print}
        /\[\/\/\]: # \('$_balise' END\)/{system("cat '"'"<(echo "$_content")"'"'"); print}
        /\[\/\/\]: # \('$_balise' START\)/,/\[\/\/\]: # \('$_balise' END\)/ {next}
        {print}
    ' README.md > $tmpfile
    cmp -s $tmpfile README.md || ( mv README.md /tmp/README.$$.md && mv $tmpfile README.md )
}

beginSuite 'Documentation'
test 'Generate README' '
    updatereadme "Usage" "$(
        echo \`\`\`
        ./ccdiff -h 2>&1
        echo \`\`\` )"

    ' ''
endSuite

