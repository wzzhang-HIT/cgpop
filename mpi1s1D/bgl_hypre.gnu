#
# File:  bgl_mpi.gnu
#
# The commenting in this file is intended for occasional maintainers who 
# have better uses for their time than learning "make", "awk", etc.  There 
# will someday be a file which is a cookbook in Q&A style: "How do I do X?" 
# is followed by something like "Go to file Y and add Z to line NNN."
#
FC = blrts_xlf90
LD = blrts_xlf90
CC = blrts_xlc
Cp = /bin/cp
Cpp = /usr/bin/cpp -P -traditional-cpp
AWK = /usr/bin/awk
ABI =
COMMDIR = mpi
 
NETCDFINC = -I/contrib/bgl/netcdf-3.6.0-p1/include 
NETCDFLIB = -L/contrib/bgl/netcdf-3.6.0-p1/lib -L/contrib/bgl/netcdf-3.6.0-pl/include 

#  Disable SERIAL library for parallel code, yes/no.

MPI = yes

#  Enable trapping and traceback of floating point exceptions, yes/no.
#  Note - Requires 'setenv TRAP_FPE "ALL=ABORT,TRACE"' for traceback.

TRAP_FPE = no

#------------------------------------------------------------------
#  precompiler options
#------------------------------------------------------------------

#DCOUPL              = -Dcoupled

Cpp_opts =   \
      $(DCOUPL) -DIBM -DMPISRC -D_R8 -I../../libtfs -I/bgl/BlueLight/ppcfloor/bglsys/include

Cpp_opts := $(Cpp_opts) -DPOSIX -D_BGL $(NETCDFINC)
 
#----------------------------------------------------------------------------
#
#                           C Flags
#
#----------------------------------------------------------------------------
 
CFLAGS = $(ABI)

ifeq ($(OPTIMIZE),yes)
  CFLAGS := $(CFLAGS) -O4 -qarch=440 -qmaxmem=-1 -qstrict
else
  CFLAGS := $(CFLAGS) -g
endif
 
#----------------------------------------------------------------------------
#
#                           FORTRAN Flags
#
#----------------------------------------------------------------------------
 
FBASE = $(ABI) -qarch=440 -qdebug=function_trace -qmaxmem=64000 -I/bgl/BlueLight/ppcfloor/bglsys/include  $(NETCDFINC) -I$(ObjDepDir)

ifeq ($(TRAP_FPE),yes)
  FBASE := $(FBASE) -qflttrap=overflow:zerodivide:enable -qspillsize=32704
endif

ifeq ($(OPTIMIZE),yes)
#  FFLAGS = $(FBASE) -g -O2 -qnoipa -qmaxmem=-1 -qstrict
  FFLAGS = $(FBASE) -O4 -qnoipa -qmaxmem=-1 -qstrict
else
  FFLAGS := $(FBASE) -g 
# below does bounds checking
# FFLAGS := $(FBASE) -g -C
endif
 
#----------------------------------------------------------------------------
#
#                           Loader Flags and Libraries
#
#----------------------------------------------------------------------------
 
LDFLAGS = $(FFLAGS) -L/bgl/BlueLight/ppcfloor/bglsys/lib 

HLIBS = -L/home/dennis/lib \
	-lHYPRE_parcsr_ls\
 	-lHYPRE_DistributedMatrixPilutSolver \
 	-lHYPRE_ParaSails \
 	-lHYPRE_Euclid \
 	-lHYPRE_MatrixMatrix \
 	-lHYPRE_DistributedMatrix \
 	-lHYPRE_IJ_mv\
 	-lHYPRE_parcsr_mv\
 	-lHYPRE_seq_mv\
 	-lHYPRE_krylov\
 	-lHYPRE_utilities\
	-L/contrib/bgl/lib -lblas440

 
#LIBS = $(NETCDFLIB) -lnetcdf -lX11
LIBS = $(NETCDFLIB) -lnetcdf $(HLIBS) -L/contrib/bgl/lib -lstackmonitor
 
ifeq ($(MPI),yes)
  LIBS := $(LIBS) -lmpich.rts -lmsglayer.rts -lrts.rts -ldevices.rts
endif

ifeq ($(TRAP_FPE),yes)
  LIBS := $(LIBS) 
endif
 
#LDLIBS = $(TARGETLIB) $(LIBRARIES) $(LIBS)
LDLIBS = $(LIBS)
 
#----------------------------------------------------------------------------
#
#                           Explicit Rules for Compilation Problems
#
#----------------------------------------------------------------------------

#----------------------------------------------------------------------------
#
#                           Implicit Rules for Compilation
#
#----------------------------------------------------------------------------
 
# Cancel the implicit gmake rules for compiling
%.o : %.f
%.o : %.f90
%.o : %.c

%.o: %.f
	@echo BGL_MPI Compiling with implicit rule $<
	$(FC) $(FFLAGS) -qfixed -c $<
	@if test -f *.mod; then mv -f *.mod $(ObjDepDir); fi
 
%.o: %.f90
	@echo BGL_MPI Compiling with implicit rule $<
	$(FC) $(FFLAGS) -qsuffix=f=f90 -qfree=f90 -c $<
	@if test -f *.mod; then mv -f *.mod $(ObjDepDir); fi
 
%.o: %.c
	@echo BGL_MPI Compiling with implicit rule $<
	$(CC) $(Cpp_opts) $(CFLAGS) -c $<

#----------------------------------------------------------------------------
#
#                           Implicit Rules for Dependencies
#
#----------------------------------------------------------------------------
 
ifeq ($(OPTIMIZE),yes)
  DEPSUF = .do
else
  DEPSUF = .d
endif

# Cancel the implicit gmake rules for preprocessing

%.c : %.C
%.o : %.C

%.f90 : %.F90
%.o : %.F90

%.f : %.F
%.o : %.F

%.h : %.H
%.o : %.H

# Preprocessing  dependencies are generated for Fortran (.F, F90) and C files
$(SrcDepDir)/%$(DEPSUF): %.F
	@echo 'BGL_MPI Making depends for preprocessing' $<
	@$(Cpp) $(Cpp_opts) $< >$(TOP)/compile/$*.f
	@echo '$(*).f: $(basename $<)$(suffix $<)' > $(SrcDepDir)/$(@F)

$(SrcDepDir)/%$(DEPSUF): %.F90
	@echo 'BGL_MPI Making depends for preprocessing' $<
	@$(Cpp) $(Cpp_opts) $< >$(TOP)/compile/$*.f90
	@echo '$(*).f90: $(basename $<)$(suffix $<)' > $(SrcDepDir)/$(@F)

$(SrcDepDir)/%$(DEPSUF): %.C
	@echo 'BGL_MPI Making depends for preprocessing' $<
#  For some reason, our current Cpp options are incorrect for C files.
#  Therefore, let the C compiler take care of #ifdef's, etc.  Just copy.
#	@$(Cpp) $(Cpp_opts) $< >$(TOP)/compile/$*.c
	$(Cp) $< $(TOP)/compile/$*.c
	@echo '$(*).c: $(basename $<)$(suffix $<)' > $(SrcDepDir)/$(@F)

# Compiling dependencies are generated for all normal .f files
$(ObjDepDir)/%$(DEPSUF): %.f
	@if test -f $(TOP)/compile/$*.f;  \
       then : ; \
       else $(Cp) $< $(TOP)/compile/$*.f; fi
	@echo 'BGL_MPI Making depends for compiling' $<
	@$(AWK) -f $(TOP)/fdepends.awk -v NAME=$(basename $<) -v ObjDepDir=$(ObjDepDir) -v SUF=$(suffix $<) -v DEPSUF=$(DEPSUF) $< > $(ObjDepDir)/$(@F)

# Compiling dependencies are generated for all normal .f90 files
$(ObjDepDir)/%$(DEPSUF): %.f90
	@if test -f $(TOP)/compile/$*.f90;  \
       then : ; \
       else $(Cp) $< $(TOP)/compile/$*.f90; fi
	@echo 'BGL_MPI Making depends for compiling' $<
	@$(AWK) -f $(TOP)/fdepends.awk -v NAME=$(basename $<) -v ObjDepDir=$(ObjDepDir) -v SUF=$(suffix $<) -v DEPSUF=$(DEPSUF) $< > $(ObjDepDir)/$(@F)

# Compiling dependencies are also generated for all .c files, but 
# locally included .h files are not treated.  None exist at this 
# time.  The two .c files include only system .h files with names 
# delimited by angle brackets, "<...>"; these are not, and should 
# not, be analyzed.  If the c programming associated with this code 
# gets complicated enough to warrant it, the file "cdepends.awk" 
# will need to test for includes delimited by quotes.
$(ObjDepDir)/%$(DEPSUF): %.c
	@if test -f $(TOP)/compile/$*.c;  \
       then : ; \
       else $(Cp) $< $(TOP)/compile/$*.c; fi
	@echo 'BGL_MPI Making depends for compiling' $<
	@echo '$(*).o $(ObjDepDir)/$(*)$(DEPSUF): $(basename $<)$(suffix $<)' > $(ObjDepDir)/$(@F)
