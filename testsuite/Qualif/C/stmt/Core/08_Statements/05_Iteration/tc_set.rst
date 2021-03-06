SC expectations regarding section 8.5: Iteration statements
===========================================================

SC expectations regarding section 8.5: Iteration statements

This sub-section of the stantard describes several “loop” statements that
execute nested statements until a condition is met.


.. qmlink:: SubsetIndexImporter

   *




.. rubric:: Testing Strategy



Each kind of loop has pecularities, but they are exercised following a common
strategy:

-   first check that nothing is covered if nothing is executed
-   then check that only the controlling condition is covered if it always
    evaluates to false
-   then check that statements nested inside the loop are all covered when the
    controlling condition evaluates to true
-   then check various combinations of GOTO’s that enter in the loop and that
    escape out of it, with a controlling condition that evaluates to both true
    and false


.. qmlink:: TCIndexImporter

   *


