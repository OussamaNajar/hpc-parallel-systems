# Makefile - AM250 Game of Life (Fortran + MPI)

MPIFC = mpif90
FC    = gfortran

FFLAGS = -O2 -Wall -Wextra

BIN_DIR = bin
SRC_DIR = src

TARGETS = serial column row mpi_mega mpi_tera latency computation_time

all: $(BIN_DIR) $(TARGETS:%=$(BIN_DIR)/%)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(BIN_DIR)/serial: $(SRC_DIR)/serial.f90
	$(FC) $(FFLAGS) -o $@ $<

$(BIN_DIR)/computation_time: $(SRC_DIR)/computation_time.f90
	$(FC) $(FFLAGS) -o $@ $<

$(BIN_DIR)/column: $(SRC_DIR)/column.f90
	$(MPIFC) $(FFLAGS) -o $@ $<

$(BIN_DIR)/row: $(SRC_DIR)/row.f90
	$(MPIFC) $(FFLAGS) -o $@ $<

$(BIN_DIR)/mpi_mega: $(SRC_DIR)/mpi_mega.f90
	$(MPIFC) $(FFLAGS) -o $@ $<

$(BIN_DIR)/mpi_tera: $(SRC_DIR)/mpi_tera.f90
	$(MPIFC) $(FFLAGS) -o $@ $<

$(BIN_DIR)/latency: $(SRC_DIR)/latency.f90
	$(MPIFC) $(FFLAGS) -o $@ $<

clean:
	rm -rf bin *.o *.mod
	
.PHONY: all clean
