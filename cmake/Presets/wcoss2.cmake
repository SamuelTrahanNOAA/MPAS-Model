set(CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS_RELEASE} -i4 -gopt -O2 -Mvect=nosse -Kieee -convert big_endian")
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -fast")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -fast")
if(MPAS_DOUBLE_PRECISION)
  # cmake doesn't correctly detect the flag for double precision reals on ifort
  set(CMAKE_Fortran_FLAGS_RELEASE "$CMAKE_Fortran_FLAGS_RELEASE -real-size 64")
  set(CMAKE_Fortran_FLAGS_DEBUG "$CMAKE_Fortran_FLAGS_RELEASE -real-size 64")
endif()
