from GRID_LRT.Staging import stage_all_LTA 
from GRID_LRT.Staging import stager_access
import os
import glob
import unittest



class Staging_Test(unittest.TestCase):
    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_stage_file(self):
        f=os.path.dirname(__file__)+'/srm_50_sara.txt'
        stage_all_LTA.main(f, test=True)

    def test_return_srmlist(self):
        f=os.path.dirname(__file__)+'/srm_50_sara.txt'
        l=stage_all_LTA.return_srmlist(f)
        self.assertTrue(len(l)==51)
