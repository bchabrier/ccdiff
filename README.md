# CCDIFF - Colored Char DIFF: Highlight file differences char by char

Similar to linux `diff` utility, but able to highlight differences char by char instead of line by line.

## Usage
[//]: # (Usage START)
```
Usage: ccdiff [options] <file1> <file2> 
ccdiff - Colored Char DIFF: Highlight file differences char by char

Options:
  -h, --help            this help

      --prefixes=PFIXS  The prefixes to use; PFIXS is a colon-separated
                        list of strings, by default '-:+: '

  Highlight mode:
   -c, --line           Differences are highlighted line by line;
                        equivalent to --threshold 100
   -l, --char           Differences are highlighted char by char
                        equivalent to --threshold 0
       --colordiff=MODE MODE can be one of:
                        - "auto": difference highlights are by line 
                          or by char depending on how similar the
                          the lines are, based on colordiff threshold 
                        - "char": equivalent to --char
                        - "line": equivalent to --line
      --threshold=PCT   Percentage of similarity between lines,
                        defining if differences are shown char by
                        char or not. Default is 50

  Colored display:
      --html            HTML output; defines --palette 'to be defined'
                        and terminates each line with <BR/>
      --palette=PALETTE The colors to use when --color is active; PALETTE is
                        a colon-separated list of terminfo capabilities;
                        default is <red>:<green>:<reset> capabilities;
                        ignored if --html is set

```
[//]: # (Usage END)

## Sample screenshot
<img alt="screenshot" src="https://github.com/user-attachments/assets/176b7892-b744-46f9-adc7-0505d19a502a" />

