! Run the original BIOME4 core (subroutine biome4 in biome4.f) on every cell of inputs.f32.
! Writes 27 Float32 per cell: biome, NPP of the 13 PFTs, LAI of the 13 PFTs (output 301:326).
! usage: biome4_driver <data dir> <output file>
program biome4_driver
implicit none
integer :: n, c
character(512) :: datadir, outfile
real, allocatable :: inputs(:,:), results(:,:)
real :: output(500)

call get_command_argument(1, datadir)
call get_command_argument(2, outfile)
open(10, file=trim(datadir)//'/ncell.txt'); read(10,*) n; close(10)
allocate(inputs(50,n), results(27,n))
open(10, file=trim(datadir)//'/inputs.f32', access='stream'); read(10) inputs; close(10)

do c = 1, n
  output = 0.
  call biome4(inputs(:,c), output)
  results(1,c)    = output(1)
  results(2:27,c) = output(301:326)
end do

open(10, file=trim(outfile), access='stream', status='replace'); write(10) results; close(10)
end program biome4_driver
