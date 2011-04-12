# ***************************************************************************
# **                         Common Utility functions                      **
# ***************************************************************************

# The following import provides both us and our clients with the context
# facilities ...

from SUITE.context import *

# -----------------
# -- contents_of --
# -----------------
def contents_of(filename):
    """Return contents of file FILENAME"""
    f = open(filename)
    contents = f.read()
    f.close()

    return contents

# --------------
# -- lines_of --
# --------------
def lines_of(filename):
    """Return contents of file FILENAME as a list of lines"""
    f = open(filename)
    contents = f.readlines()
    f.close()

    return contents

# -------------
# -- to_list --
# -------------
def to_list(blob):
    """Turn input BLOB into a list if it isn't already. Handle None
       and whitespace separated strings. Return empty list otherwise."""

    if isinstance (blob, list):
        return blob

    if blob == None:
        return []

    if isinstance (blob, str):
        return blob.split ()

    return []

# ------------------
# -- text_to_file --
# ------------------
def text_to_file(text, filename="tmp.list"):
    """Write TEXT to file FILENAME. Overwrite current contents.
    Return FILENAME."""

    f = open (filename, "w")
    f.write (text)
    f.close ()
    return filename

# ------------------
# -- list_to_file --
# ------------------
def list_to_file(l, filename="tmp.list"):
    """Write list L to file FILENAME, one item per line. Typical use is
       to generate response files. Return FILENAME."""

    return text_to_file ('\n'.join (l) + '\n', filename)

# --------------
# -- gprbuild --
# --------------
def gprbuild(project, gargs=None, cargs=None, largs=None):
    """Cleanup & build the provided PROJECT file using gprbuild, passing
    GARGS/CARGS/LARGS as gprbuild/cargs/largs command-line switches
    (in addition to the switches required by the infrastructure.

    The *ARGS arguments may be either: None, a string containing
    a space-separated list of options, or a list of options."""

    # Enforce -g, always needed and possibly not be included by our base
    # runtime project file, e.g. ravenscar

    all_gargs = ['-q', '-f', '-XSTYLE_CHECKS=', '-p', '-P%s' % project]

    all_gargs += thistest.gprconfoptions
    all_gargs += to_list(gargs)

    all_cargs = to_list(cargs) + to_list(COMMON_CARGS)
    if all_cargs:
        all_cargs.insert(0, '-cargs')

    all_largs = to_list(largs)
    if all_largs:
        all_largs.insert(0, '-largs')

    thistest.cleanup(project)

    ofile = "gprbuild.out"
    p = Run([GPRBUILD] + all_gargs + all_cargs + all_largs,
            output=ofile, timeout=thistest.options.timeout)
    thistest.stop_if (
        p.status != 0, FatalError("gprbuild exit in error", ofile))

# ------------
# -- gprfor --
# ------------
def gprfor(mains, prjid="gen", srcdirs="src"):
    """Generate a simple PRJID.gpr project file to build executables for each
    main source file in the MAINS list, sources in SRCDIRS. Inexistant
    directories in SRCDIRS are ignored. Return the gpr file name.
    """

    mains = to_list(mains)
    srcdirs = to_list(srcdirs)

    # Fetch the support project file template
    template = contents_of (os.path.join (ROOT_DIR, "template.gpr"))

    # Instanciate the template fields. Turn the list of main sources into
    # the proper comma separated sequence of string literals for the Main
    # GPR attribute. Likewise for source dirs, plus filter on existence.

    # The existence check allows widening the set of tentative dirs while
    # preventing complaints from gprbuild about inexistent ones.

    gprmains = ', '.join(['"%s"' % m for m in mains])
    srcdirs  = ', '.join(['"%s"' % d for d in srcdirs if os.path.exists(d)])

    # Remove trailing comma on srcdirs, in case none of the provided ones
    # exists, which would produce an invalid gpr file.

    basegpr = (thistest.options.rtsgpr
               if thistest.options.rtsgpr else "%s/support/base" % ROOT_DIR)

    gprtext = template % {'prjname': prjid,
                          'extends': 'extends "%s"' % basegpr,
                          'srcdirs': srcdirs.rstrip(', '),
                          'gprmains': gprmains}

    # Dump the new contents into the target gpr file and return

    return text_to_file (text = gprtext, filename = prjid + ".gpr")

# --------------------
# -- maybe_valgrind --
# --------------------
def maybe_valgrind(command):
    """Return the input COMMAND list, with 'valgrind -q' prepended if
    valgrind is available and was not disabled through options.
    """
    if (not thistest.options.disable_valgrind) and which(VALGRIND) != '':
        command = [VALGRIND, '-q'] + command
    return command

# ----------
# -- xcov --
# ----------
def xcov(args, out=None, inp=None, register_failure=True):
    """Run xcov with arguments ARGS, timeout control, valgrind control if
    available and enabled, output directed to OUT and failure registration
    if register_failure is True. Return the process status descriptor. ARGS
    may be a list or a whitespace separated string."""

    # make ARGS a list from whatever it is, to allow unified processing
    args = to_list (args)
    retry = 0

    if thistest.options.trace_dir is not None:
        # Bootstrap - run xcov under xcov

        # QEMU's "user" mode is showing some instabilities on x86-linux;
        # see J618-020. So try to re-run if failure. And these instabilities
        # are very visible in 'run' mode; so do the bootstrap for 'coverage'
        # mode only.
        if len (args) > 0 and args[0] == 'coverage':
            thistest.current_test_index += 1
            args = ['run', '-t', 'i386-linux',
                    '-o', os.path.join(thistest.options.trace_dir,
                                       str(thistest.current_test_index)
                                       + '.trace'),
                    which(XCOV), '-eargs'] + args
            retry = 3

    # Execute, check status, raise on error and return otherwise
    p = Run(maybe_valgrind([XCOV]) + args,
            output=out, input=inp, timeout=thistest.options.timeout)
    while p.status != 0 and retry > 0:
        retry -= 1
        p = Run(maybe_valgrind([XCOV]) + args,
                output=out, input=inp, timeout=thistest.options.timeout)
    thistest.stop_if(
        register_failure and p.status != 0,
        FatalError('"xcov ' + ' '.join(args) + '" exit in error', out))
    return p

# ----------
# -- xrun --
# ----------
def xrun(args, out=None):
    """Run <xcov run> with arguments ARGS for the current target."""

    # We special case xcov --run to pass an extra --target option and
    # force a dummy input to prevent mysterious qemu misbehavior when
    # input is a terminal.

    nulinput = "devnul"
    touch(nulinput)

    # On leon-elf, qemu is stopped by generating a double-fault.  This
    # crashes the board and therefore qemu exits with an error message.
    # As this is expected, we don't stop the test because of exit status.

    # Compute our --target argument to xcov run.  If we have a specific
    # target board specified, use that.  Fallback on our general target
    # triplet otherwise.

    if thistest.options.board:
        targetarg = thistest.options.board
    else:
        targetarg = env.target.triplet

    return xcov (['run', '--target=' + targetarg] + to_list(args),
                 inp=nulinput, out=out, register_failure=False)
# -----------
# -- match --
# -----------
def match(pattern, filename, flags=0):
    """Whether regular expression PATTERN could be found in FILENAME"""
    return re.search(pattern, contents_of(filename), flags) is not None

# -------------
# -- differs --
# -------------
def differs (file1, file2):
    """Returns True if the content of the two files are different"""
    diff_string = diff (file1, file2)
    return diff_string != ''

# --------
# -- do --
# --------
def do(command):
    """Execute COMMAND. Abort and dump output on failure. Return output
    otherwise."""

    ofile = "cmd_.out"
    p = Run(to_list (command), output=ofile)

    thistest.stop_if(p.status != 0,
        FatalError("command '%s' failed" % command, ofile))

    return contents_of(ofile)

# -------------
# -- compile --
# -------------
def compile(source, options):
    """Compile SOURCE with the target compiler, passing OPTIONS on the
    command line."""
    do("%s-gcc -c %s %s"  % (env.target.triplet, options, source))

# -----------
# -- frame --
# -----------
class frame:

    def register(self, text):
        if len(text) > self.width:
            self.width = len(text)

    def display(self):
        thistest.log('\n' * self.pre + self.char * (self.width + 6))
        for text in self.lines:
            thistest.log("%s %s %s" % (
                self.char * 2, text.center(self.width), self.char*2))
        thistest.log(self.char * (self.width + 6) + '\n' * self.post)

    def __init__(self, text, char='o', pre=1, post=1):
        self.pre  = pre
        self.post = post
        self.char = char

        self.width = 0
        self.lines = text.split('\n')
        [self.register(text) for text in self.lines]

# ==========================
# == FatalError Exception ==
# ==========================

# to raise when processing has to stop

class FatalError(Exception):
    def __init__(self,comment,output=None):
        if output != None:
            comment += '. Output was:\n'+contents_of(output)
        self.comment = comment

    def __str__(self):
        return self.comment

