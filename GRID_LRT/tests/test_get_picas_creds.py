from GRID_LRT.auth import get_picas_credentials as get_pc
import os 
import glob
import unittest
import tempfile



class picas_cred_test(unittest.TestCase):
    def setUp(self):
        pass

    def tearDown(self):
        pass


    def test_info_logging(self):
        get_pc.infolog('infolog')



    def test_debug_logging(self):
        get_pc.debuglog('debuglog')



    def test_warn_logging(self):
        get_pc.warnlog('warnlog')

    def test_get_cred_from_file(self):
        f = tempfile.NamedTemporaryFile(delete=False)
        with open(f.name,'w') as _file:
            _file.write('user=testuser\n')
            _file.write('password=testpasswd\n')
            _file.write('database=testdatabase\n')
        pc = get_pc.picas_cred(source_file=f.name)
        self.assertTrue(pc.user=='testuser')
        self.assertTrue(pc.password=='testpasswd')
        self.assertTrue(pc.database=='testdatabase')
        os.remove(f.name)

    def test_get_creds_from_init(self):
         pc = get_pc.picas_cred(usr='tusr', pwd='tpwd', dbn='tdb')
         self.assertTrue(pc.user=='tusr')
         self.assertTrue(pc.password=='tpwd')
         self.assertTrue(pc.database=='tdb')


if __name__ == '__main__':
    unittest.main() 
