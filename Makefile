include ../mcl/common.mk
LIB_DIR=lib
OBJ_DIR=obj
EXE_DIR=bin
CFLAGS += -std=c++11

SRC_SRC=bls.cpp bls_c.cpp
TEST_SRC=bls_test.cpp bls_c384_test.cpp
SAMPLE_SRC=bls_smpl.cpp bls_tool.cpp

CFLAGS+=-I../mcl/include
UNIT?=6
ifeq ($(UNIT),4)
  CFLAGS+=-D"MCLBN_FP_UNIT_SIZE=4"
  GO_TAG=bn256
endif
ifeq ($(UNIT),6)
  CFLAGS+=-D"MCLBN_FP_UNIT_SIZE=6"
  GO_TAG=bn384
endif

sample_test: $(EXE_DIR)/bls_smpl.exe
	python bls_smpl.py

SHARE_BASENAME_SUF?=_dy
##################################################################
BLS_LIB=$(LIB_DIR)/libbls.a

LIB_OBJ=$(OBJ_DIR)/bls.o

$(BLS_LIB): $(LIB_OBJ)
	$(AR) $@ $(LIB_OBJ)

MCL_LIB=../mcl/lib/libmcl.a
BN384_LIB=../mcl/lib/libmclbn384.a

$(MCL_LIB):
	$(MAKE) -C ../mcl

##################################################################

BLS384_LIB=$(LIB_DIR)/libbls384.a
BLS384_SLIB=$(LIB_DIR)/libbls384$(SHARE_BASENAME_SUF).$(LIB_SUF)
lib: $(BLS_LIB) $(BLS384_SLIB)

$(BLS384_LIB): $(LIB_OBJ) $(OBJ_DIR)/bls_c384.o
	$(AR) $@ $(LIB_OBJ) $(OBJ_DIR)/bls_c384.o

$(BLS384_SLIB): $(BLS384_LIB) $(BN384_LIB)
#	$(PRE)$(CXX) -shared -o $@ -Wl,--whole-archive $(BLS384_LIB) $(BN384_LIB) $(MCL_LIB) -Wl,--no-whole-archive
	$(PRE)$(CXX) -shared -o $@ -Wl,--whole-archive $(BLS384_LIB) -Wl,--no-whole-archive

VPATH=test sample src

.SUFFIXES: .cpp .d .exe

$(OBJ_DIR)/%.o: %.cpp
	$(PRE)$(CXX) $(CFLAGS) -c $< -o $@ -MMD -MP -MF $(@:.o=.d)

$(OBJ_DIR)/bls_c384.o: bls_c.cpp
	$(PRE)$(CXX) $(CFLAGS) -c $< -o $@ -MMD -MP -MF $(@:.o=.d) -DMBN_FP_UNIT_SIZE=6

$(EXE_DIR)/%.exe: $(OBJ_DIR)/%.o $(BLS_LIB) $(BLS384_LIB) $(MCL_LIB)
	$(PRE)$(CXX) $< -o $@ $(BLS_LIB) $(BLS384_LIB) -lmcl -L../mcl/lib $(LDFLAGS)

SAMPLE_EXE=$(addprefix $(EXE_DIR)/,$(SAMPLE_SRC:.cpp=.exe))
sample: $(SAMPLE_EXE) $(BLS_LIB)

TEST_EXE=$(addprefix $(EXE_DIR)/,$(TEST_SRC:.cpp=.exe))
test: $(TEST_EXE)
	@echo test $(TEST_EXE)
	@sh -ec 'for i in $(TEST_EXE); do $$i|grep "ctest:name"; done' > result.txt
	@grep -v "ng=0, exception=0" result.txt; if [ $$? -eq 1 ]; then echo "all unit tests succeed"; else exit 1; fi

test_go: go/bls/bls.go go/bls/bls_test.go $(BLS384_SLIB)
	cd go/bls && env CGO_CFLAGS="-I../../include -I../../../mcl/include" CGO_LDFLAGS="-L../../lib -L../../../mcl/lib" LD_LIBRARY_PAHT=../../lib go test .
#	cd go/bls && go test -tags $(GO_TAG) -v .

clean:
	$(RM) $(BLS_LIB) $(OBJ_DIR)/*.d $(OBJ_DIR)/*.o $(EXE_DIR)/*.exe $(GEN_EXE) $(ASM_SRC) $(ASM_OBJ) $(LIB_OBJ) $(LLVM_SRC) $(BLS384_SLIB)

ALL_SRC=$(SRC_SRC) $(TEST_SRC) $(SAMPLE_SRC)
DEPEND_FILE=$(addprefix $(OBJ_DIR)/, $(ALL_SRC:.cpp=.d))
-include $(DEPEND_FILE)

# don't remove these files automatically
.SECONDARY: $(addprefix $(OBJ_DIR)/, $(ALL_SRC:.cpp=.o))
 
