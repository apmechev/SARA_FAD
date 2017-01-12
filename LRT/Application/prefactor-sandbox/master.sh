#!/bin/bash

# ===================================================================== #
# authors: Alexandar Mechev <apmechev@strw.leidenuniv.nl> --Leiden	#
#	   Natalie Danezi <anatoli.danezi@surfsara.nl>  --  SURFsara    #
#          J.B.R. Oonk <oonk@strw.leidenuniv.nl>    -- Leiden/ASTRON    #
#                                                                       #
# helpdesk: Grid Services <grid.support@surfsara.nl>    --  SURFsara    #
#                                                                       #
# usage: ./prefactor.sh [OBSID] [SURL_SUBBAND] 	                        #
#        [AVG_FREQ_STEP] [AVG_TIME_STEP] [DO_DEMIX] [DEMIX_FREQ_STEP]	#
#	 [DEMIX_TIME_STEP] [DEMIX_SOURCES] [SELECT_NL]                  #
#                                                                       #
#  note: demixer.freqstep = [AVG_FREQ_STEP] 'averages data in freq'     #
#        demixer.timestep = [AVG_TIME_STEP] 'averages data in time'     #
#        demixer.demixfreqstep = [DEMIX_FREQ_STEP] 'demix done on time' #
#        demixer.demixtimestep = [DEMIX_TIME_STEP] 'demix done on time' #
#                                                                       #
#        SELECT_NL (bool): True = keep only NL , False=keep all         #
#        DO_DEMIX  (bool): True or False                                #
#        DEMIX_SOURCES (string): user defined ( ex. [Cas,CygA] )        #
#                                                                       #
#  note: add 'Ateam_LBA.sky.tar' to sandbox and untar in avg_dmx.py     #
#                                                                       #
#                                                                       #
# description:                                                          #
#       Set Lofar environment, fetch input from Grid Storage,           #
#       do averaging or demixing, then flag output with std. strategy,  #
#       finally copy the output to a (temporary) Grid Storage           #
# ===================================================================== #

#--- NEW SD ---
JOBDIR=${PWD}
OLD_PYTHON=$( which python)
echo $OLD_PYTHON

########################
### Importing functions
########################

source bin/setup_lofar_env.sh
source bin/print_worker_info.sh
source bin/setup_downloads.sh 
source bin/setup_run_dir.sh
source bin/print_job_info.sh

#########################
#Parse input arguments
########################

TEMP=`getopt -o octlspduwT: --long obsid:,calobsid:,token:,lofdir:,startsb:,parset:,picasdb:,picasuname:,picaspwd:,pipetype: -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 9 ; fi #exit 9=> master.sh got bad argument

PARSET="Pre-Facet-Target.parset"
eval set -- "$TEMP"
echo $TEMP
while [ true ]
do
    case $1 in
    -o | --obsid ) OBSID="$2" ; shift  ;;
    -c | --calobsid ) CAL_OBSID="$2"; shift  ;;
    -t | --token ) TOKEN="$2"; shift  ;;
    -l | --lofdir ) LOFAR_PATH="$2";shift ;;
    -s | --startsb) STARTSB="$2";shift ;;
    -p | --parset ) PARSET="$2"; shift  ;;
    -d | --picasdb ) PICAS_DB="$2"; shift ;;
    -u | --picasuname ) PICAS_USR="$2"; shift ;;
    -w | --picaspwd ) PICAS_USR_PWD="$2" ; shift ;;
    -T | --pipetype ) PIPELINE="$2"; shift ;;
    -- ) shift; break;;
    -*) echo "$0: error - unrecognized option $1" 1>&2; exit 8;; #exit 8=> Unknown argument
    * ) break;;
    esac
    shift
done

############################
#Initialize the environment
############################

echo "INITIALIZE LOFAR FROM SOFTDRIVE, in "$LOFAR_PATH
setup_LOFAR_env $LOFAR_PATH      ##Imported from setup_LOFAR_env.sh

# NEW NB we can't assume the home dir is shared across all Grid nodes.
echo  "var LOFARDATAROOT: " ${LOFARDATAROOT}
echo  "setup" "adding symbolic link for EPHEMERIDES and GEODETIC data into homedir"
ln -s ${LOFARDATAROOT} .
ln -s ${LOFARDATAROOT} ~/

trap cleanup EXIT #This ensures the script cleans_up regardless of how and where it exits

print_info                      ##Imported from bin/print_worker_info

if [[ -z "$PARSET" ]]; then
    ls "$PARSET"
    echo "not found"
    exit 30  #exit 30=> Parset doesn't exist
fi

setup_run_dir                     #imported from bin/setup_run_dir.sh

trap '{ echo "Trap detected segmentation fault... status=$?"; $OLD_PYTHON update_token_status.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} "segfault"; sleep 5; rm -rf ${RUNDIR}/*;  exit 2; }' SIGSEGV #exit 2=> SIGSEGV caught

trap '{ echo "Trap detected interrupt ... status=$?"; $OLD_PYTHON update_token_status.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} "interrupted"; rm -rf ${RUNDIR}/*;  exit 3; }' SIGHUP SIGINT SIGTERM  #exit 3=> INTerrupt caught


echo "RUN DIRECTORY IS "${RUNDIR}
sed -i "s?LOFAR_ROOT?${LOFAR_PATH}?g" pipeline.cfg
echo  "replaced LOFAR_PATH in pipeline.cfg"
pwd

print_job_info                  #imported from bin/print_job_info.sh

echo ""
echo "---------------------------------------------------------------------------"
echo "START PROCESSING" $OBSID "SUBBAND:" $STARTSB
echo "---------------------------------------------------------------------------"


####
# Download the data on the node 10 subbands at a time while ignoring subbands that 
# cannot be downloaded (so that the job doesn't hang)
####
echo ""
echo "---------------------------"
echo "Starting Data Retrieval"
echo "---------------------------"
echo "Get subbands "

sleep 6

setup_downloads $PIPELINE

echo "Downloading $( wc -l srm.txt | awk '{print $1}' ) files"

if [[ -z $( echo $PIPELINE | grep targ1 ) ]]
 then
  $OLD_PYTHON  wait_for_dl.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD}
fi

if [[ -z $( echo $PIPELINE | grep targ2 ) ]]
 then
  $OLD_PYTHON update_token_status.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} 'downloading'
  while read -r line ; do SB=$( echo ${line} | sed  "s\srm://lofar-srm.fz-juelich.de:8443\gsiftp://dcachepool12.fz-juelich.de:2811\g" | sed  "s\srm://srm.grid.sara.nl:8443\gsiftp://gridftp.grid.sara.nl:2811\g"); globus-url-copy $SB ./ ; done < srm.txt
  wait  #####REPLACE THIS
 for i in `ls *tar`;do tar -xvf $i; done 
 rm *tar
 else
  $OLD_PYTHON update_token_status.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} 'downloading'
  cat srm.txt | xargs -I{} globus-url-copy  {} $PWD/
  for i in `ls *gz`; do tar -zxf $i; done
  mv prefactor/results/L* ${RUNDIR}
fi

 

$OLD_PYTHON update_token_status.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} 'downloaded'

# - step2 finished check contents
echo "step2 finished, list contents"
ls -l $PWD
du -hs $PWD
du -hs $PWD/*

echo "Replacing "$PWD" in the prefactor parset"

sed -i "s?PREFACTOR_SCRATCH_DIR?$(pwd)?g" ${PARSET}
sed -i "s?PREFACTOR_SCRATCH_DIR?$(pwd)?g" pipeline.cfg


#Check if any files match the target, if so, download the calibration tables matching the calibrator OBSID. If no tables are downloaded, exit with an error message.
if [[ ! -z ${CAL_OBSID}  ]]
then
 echo "Getting solutions from obsid "$CAL_OBSID
 globus-url-copy gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/sksp/spectroscopy-migrated/prefactor/numpy_${CAL_OBSID}.tar file:`pwd`/cal_solutions.tar
 wait
 if [[ -e cal_solutions.tar ]]
  then
    tar -xvf cal_solutions.tar
 else
    exit 31 #exit 31=> numpy solutions do not get downloaded
 fi
fi

if [[ ! -z ${CAL_OBSID} ]]
then
pipelinetype=$PIPELINE
elif [[ ! -z $( echo $PARSET | grep Initial-Subtract ) ]]
then
pipelinetype="pref.insub"
else
pipelinetype="pref.cal"
fi

sed -i "s?sortmap_target\.argument\.firstSB.*=?sortmap_target\.argument\.firstSB    = ${STARTSB}?g" *parset 

echo "Pipeline type is "$pipelinetype
echo "Adding $OBSID and $pipelinetype into the tcollector tags"
sed -i "s?\[\]?\[\ \"obsid=${OBSID}\",\ \"pipeline=${pipelinetype}\"\]?g" openTSDB_tcollector/collectors/etc/config.py

if [[ ! -z $( echo $pipelinetype |grep targ1 ) ]]
  then
    echo "running taql on "$( ls -d *${OBSID}*SB*  )"/SPECTRAL_WINDOW"
    FREQ=$( echo "select distinct REF_FREQUENCY from $( ls -d *${OBSID}*SB* )/SPECTRAL_WINDOW"| taql | tail -2 | head -1)
    A_SBN=$( $OLD_PYTHON update_token_freq.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} ${FREQ} )
    echo "Frequency is "${FREQ}" and Absolute Subband is "${A_SBN}
    mv prefactor/results/L*ms ${RUNDIR}  #moves untarred results from targ1 to ${RUNDIR} 
fi

echo ""
echo "execute generic pipeline"
$OLD_PYTHON update_token_status.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} 'starting_generic_pipeline'
$OLD_PYTHON update_token_progress.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} output ${PARSET} &


echo "start tCollector in dryrun mode"
cd openTSDB_tcollector/
mkdir logs
./tcollector.py -H spui.grid.sara.nl -p 4242  &
TCOLL_PID=$!
cd ..

genericpipeline.py ${PARSET} -d -c pipeline.cfg > output  &
wait # without wait, traps aren't caught

$OLD_PYTHON update_token_status.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} 'processing_finished'

echo "killing tcollector"
kill $TCOLL_PID


#####################
# Make plots
#
######################

if [[ ! -z $( echo $pipelinetype |grep targ2 ) ]]
  then
    ./prefactor/scripts/plot_solutions_all_stations.py -p $( ls -d ${RUNDIR}/prefactor/results/*ms )/instrument_directionindependent/ ${JOBDIR}/GSM_CAL_${OBSID}_ABN${STARTSB}_plot.png
fi

xmlfile=$( find . -name "*statistics.xml" 2>/dev/null)
cp piechart/autopie.py .
./autopie.py ${xmlfile} PIE_${OBSID}.png

find . -name "PIE*png"|xargs tar -zcf pngs.tar.gz
find . -name "*.png" -exec cp {} ${JOBDIR} \;
cp PIE_${OBSID}.png ${JOBDIR}
cp ./prefactor/cal_results/*png ${JOBDIR}
find ./prefactor/cal_results/ -name "*npy"|xargs tar -cf numpys.tar
tar --append --file=numpys.tar pngs.tar.gz
find . -name "*tcollector.out" | xargs tar -cf profile.tar
find . -iname "*statistics.xml" -exec tar -rvf profile.tar {} \;
find . -name "*png" -exec tar -rvf profile.tar {} \;
tar --append --file=profile.tar output
tar -zcvf profile.tar.gz profile.tar
find ./prefactor/results/ -iname "*h5" -exec tar -rvf numpys.tar {} \;

echo "Numpy files found:"
find . -name "*npy"
#
# - step3 finished check contents
more output
#more openTSDB_tcollector/logs/*
OBSID=$( echo $(head -1 srm.txt) |grep -Po "L[0-9]*" | head -1 )
echo "Saving profiling data to profile_"$OBSID_$( date  +%s )".tar.gz"
globus-url-copy file:`pwd`/profile.tar.gz gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/disk/profiling/profile_${OBSID}_$( date  +%s ).tar.gz &
wait
if [[ $( grep "finished unsuccesfully" output) > "" ]]
then
     $OLD_PYTHON update_token_status.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} 'prefactor_crashed!'
     echo "Pipeline did not finish, tarring work and run directories for re-run"
     RERUN_FILE=$OBSID"_"$STARTSB"prefactor_error.tar"
     echo "Will be  at gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/sksp/spectroscopy-migrated/prefactor/error_states"$RERUN_FILE
#     tar -cf $RERUN_FILE prefactor/
#     globus-url-copy file:`pwd`/$RERUN_FILE gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/sksp/spectroscopy-migrated/prefactor/error_states/$RERUN_FILE
   if [[ $(hostname -s) != 'loui' ]]; then
    echo "removing RunDir"
    rm -rf ${RUNDIR}
   fi
   if [[ $( grep "bad_alloc" output) > "" ]]
   then
	echo "Prefactor crashed because of bad_alloc. Not enough memory"
	exit 16 #exit 16=> Bad_alloc error in prefactor
   fi
   if [[ $( grep "-9" output) > "" ]]
   then
        echo "Prefactor crashed because of dppp: Not enough memory"
        exit 15 #exit 15=> dppp memory error in prefactor
   fi

   if [[ $( grep "RegularFileIO" output) > "" ]]
   then
        echo "Prefactor crashed because of bad download"
        exit 17 #exit 17=> Files not downloaded fully
   fi

   exit 99 #exit 99=> generic prefactor error
fi 
$OLD_PYTHON update_token_status.py ${PICAS_DB} ${PICAS_USR} ${PICAS_USR_PWD} ${TOKEN} 'uploading_results'
echo "step3 finished, list contents"



# STORE PROCESSING RESULTS AND CLEAN UP
echo ""
echo "---------------------------------------------------------------------------"
echo "Copy the output from the Worker Node to the Grid Storage Element"
echo "---------------------------------------------------------------------------"

echo "JOBDIR, RUNDIR, PWD: ", ${JOBDIR}, ${RUNDIR}, ${PWD}

echo "Copy output to the Grid SE"

# copy the output tarball to the Grid storage
OBSID=$( echo $(head -1 srm.txt) |grep -Po "L[0-9]*" | head -1 )

echo "copying the Results"
#globus-url-copy file:`pwd`/instruments.tar gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/sksp/spectroscopy-migrated/prefactor/instr_$OBSID.tar

if [[ ! -z $( grep subtract ${PIPELINE}  ) ]]
   then
   OBSID="Init_"${OBSID}
   CAL_OBSID="2" #do this nicer
fi

if [[ ! -z $( echo ${PIPELINE} | grep targ ) ]] #if target is defined, CALOBSID is also defined to differentiate from OBSID
then
 tar -zcvf results.tar.gz prefactor/results/L*
 if [[ ! -z $( echo ${PIPELINE} | grep targ1 ) ]]
  then
   uberftp -mkdir gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/sksp/spectroscopy-migrated/prefactor/SKSP/${OBSID}
   globus-url-copy file:`pwd`/results.tar.gz gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/sksp/spectroscopy-migrated/prefactor/SKSP/${OBSID}/t1_${OBSID}_AB${A_SBN}_SB${STARTSB}_.tar.gz
    wait
  else
   uberftp -mkdir gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/sksp/distrib/SKSP/${OBSID}
   globus-url-copy file:`pwd`/results.tar.gz gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/sksp/distrib/SKSP/${OBSID}/GSM_CAL_${OBSID}_ABN_${STARTSB}.tar.gz
    wait
   ./prefactor/scripts/plot_solutions_all_stations.py -p ${RUNDIR}/prefactor/results/$( ls -d ${RUNDIR}/prefactor/results/*ms )/instrument_directionindependent/ GSM_CAL_${OBSID}_ABN${STARTSB}_plot.png
   #globus-url-copy file:`pwd`/GSM_CAL_${OBSID}_ABN${STARTSB}_plot.png gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/sksp/distrib/SKSP/${OBSID}/GSM_CAL_${OBSID}_ABN${STARTSB}_plot.png  
  fi
else
	 globus-url-copy file:`pwd`/numpys.tar gsiftp://gridftp.grid.sara.nl:2811/pnfs/grid.sara.nl/data/lofar/user/sksp/spectroscopy-migrated/prefactor/cal_sols/${OBSID}_solutions.tar
        wait
fi

function cleanup(){
if [[ "$?" != "0" ]]; then
   echo "Problem copying final files to the Grid. Clean up and Exit now..."
   cp log_$name logtar_$name.fa ${JOBDIR}
   cd ${JOBDIR}

   if [[ $(hostname -s) != 'loui' ]]; then
    echo "removing RunDir"
    rm -rf ${RUNDIR} 
   fi
   exit 21 #exit 21=> cannot upload final files
fi
echo ""

echo ""
echo "copy echos to the Job home directory and clean temp files in scratch"
cp out* ${JOBDIR}
cd ${JOBDIR}
cp pngs.tar.gz ${JOBDIR}

if [[ $(hostname -s) != 'loui' ]]; then
    echo "removing RunDir"
    rm -rf ${RUNDIR} 
fi
ls -l ${RUNDIR}
echo ""
echo "listing final files in Job directory"
ls -allh $PWD
echo ""
du -hs $PWD
}

echo ""
echo `date`
echo "---------------------------------------------------------------------------"
echo "FINISHED" $OBSID "SUBBAND:" $SURL_SUBBAND
echo "---------------------------------------------------------------------------"

