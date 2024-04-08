#!/bin/bash

# Pre-run script, runs after payu sets up the work directory and before the model is run

# Sets the appropriate land use for the model start date.
# The model doesn't vary the land use itself, this is instead done as a
# post-processing step - the old land use values are moved to a new STASH code,
# and new land use values are read in from an external file.

source  /etc/profile.d/modules.sh
module use /g/data/hh5/public/modules
module load conda/analysis3

set -eu

# Input land use file
lu_file=$1

# Get the current year from field t2_year of the restart file
year=$(mule-pumf --component fixed_length_header work/atmosphere/restart_dump.astart | sed -n 's/.*t2_year\s*:\s*//p')
#source scripts/utils.sh
#year=$(get_payu_start_year)
#year=1851

# If that year is in the land use file, save a single timestep to a new netcdf file
if cdo selyear,$(( year )) -chname,fraction,field1391 $lu_file work/atmosphere/land_frac.nc; then

    # Back up the original restart file
    mv --verbose work/atmosphere/restart_dump.astart work/atmosphere/restart_dump.astart.orig

    # Use the CSIRO script to set the land-use
    echo "Updating cable vegfrac for year ${year}"
    python scripts/update_cable_vegfrac.py -i work/atmosphere/restart_dump.astart.orig -o work/atmosphere/restart_dump.astart -f work/atmosphere/land_frac.nc
fi

# Update the forest thinning data in the restart file.
module load python2/2.7.16
module use ~access/modules
module load pythonlib/umfile_utils
echo "Updating thinning data for year ${year}"
python2 scripts/um_replace_field_multilevel.py \
        -v 916 \
        -V thinRatio \
        -n /g/data/p66/txz599/data/luc_hist_thinning/cableCMIP6_thin_${year}.nc \
        work/atmosphere/restart_dump.astart
module unload python2
