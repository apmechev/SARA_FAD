# ===================================================================== #
# author: Ron Trompert <ron.trompert@surfsara.nl>	--  SURFsara    #
# helpdesk: Grid Services <grid.support@surfsara.nl>    --  SURFsara	#
#                                                            	        #
# usage: python state.py						#
# description:                                                       	#
#	Display the status of each file listed in "files". The paths 	#
#	should have the '/pnfs/...' format. Script output:		#
#		ONLINE: means that the file is only on disk		#
#		NEARLINE: means that the file in only on tape		#
#		ONLINE_AND_NEARLINE: means that the file is on disk	#
#				     and tape				#
# ===================================================================== #

#!/usr/bin/env python

import pythonpath
import gfal
import time
import re
import sys
from string import strip

def main(filename):
	file_loc=location(filename)
	return (replace(filename,file_loc))

def location(filename):
	locs_options=['s','j','p']
	with open(filename,'r') as f:
		line=f.readline()
	 
	file_loc=[locs_options[i] for i in range(len(locs_options)) if ["sara" in line,"juelich" in line, not "sara" in line and not "juelich" in line][i] ==True]
	return file_loc[0]

def replace(filename,file_loc):
	if file_loc=='p':
		m=re.compile('/lofar')
		repl_string="srm://lta-head.lofar.psnc.pl:8443/srm/managerv2?SFN=/lofar"
		print("Files are in Poznan")
	else:
		m=re.compile('/pnfs')
		if file_loc=='j':
			repl_string="srm://lofar-srm.fz-juelich.de:8443/srm/managerv2?SFN=/pnfs/"
			print("Files are in Juleich")
		elif file_loc=='s':
			repl_string="srm://srm.grid.sara.nl:8443/srm/managerv2?SFN=/pnfs"
			print("files are on SARA")
		else:
			sys.exit()
	nf=100
	
	f=open(filename,'r')
	urls=f.readlines()
	f.close()
	
	surls=[]
	for u in urls:
	    surls.append(m.sub(repl_string,strip(u)))
	#    surls.append(m.sub('srm://lofar-srm.fz-juelich.de:8443/srm/managerv2?SFN=/pnfs/',strip(u)))
	
	mx=len(surls)
	locality=[]

	i=0
	while i<mx:
	    req={}
	    mxi=min(i+nf,mx)
	    s=surls[i:mxi]
	    req.update({'surls':s})
	    req.update({'setype':'srmv2'})
	    req.update({'no_bdii_check':1})
	    req.update({'srmv2_lslevels':1})
	    req.update({'protocols':['gsiftp']})
	    a,b,c=gfal.gfal_init(req)
	    a,b,c=gfal.gfal_ls(b)
	    a,b,c=gfal.gfal_get_results(b)
	    for j in range(0,len(c)):
	       if c[j]['locality']=='NEARLINE':
			colour="\033[31m"
	       else:
			colour="\033[32m"
	       print c[j]['surl']+" "+colour+c[j]['locality']+"\033[0m"
	       locality.append([c[j]['surl'],c[j]['locality']])
	    i=i+nf
	    time.sleep(1)
	return(locality)

if __name__=='__main__':
	if len(sys.argv)==2:
		sys.exit(main(sys.argv[1]))
	else: 
		sys.exit(main('files'))