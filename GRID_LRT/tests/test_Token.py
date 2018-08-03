import random
import string
from GRID_LRT import Token 
from GRID_LRT.get_picas_credentials import picas_cred
import os
import glob
import unittest
import sys

vers=str(sys.version_info[0])+"."+str(sys.version_info[1])
T_TYPE="travis_ci_test"+vers
TOKEN="travis_getSBX_test"+vers


class TokenTest(unittest.TestCase):
    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_create_Token(self):
        T_TYPE = ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(5))
        th = Token.Token_Handler(t_type=T_TYPE, srv="http://localhost:5984/",
                                 uname='', pwd="", dbn='test_db')
        self.assertTrue(th.get_db(uname='', pwd="",  dbn='test_db', 
            srv="http://localhost:5984/").name == 'test_db')
        th.create_token(keys={'test_suite':'Token'}, append="Tokentest", attach=[])
        th.add_status_views()
        th.add_overview_view()
        th.load_views()
        views = th.views
        self.assertTrue('todo' in views.keys())
        self.assertTrue('locked' in views.keys())
        self.assertTrue('error' in views.keys())
        self.assertTrue('done' in views.keys())
        self.assertTrue('overview_total' in views.keys())
        th.purge_tokens()


    def test_delete_token(self):
        T_TYPE = ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(5))
        th = Token.Token_Handler(t_type=T_TYPE, srv="http://localhost:5984/",
                                 uname="", pwd="", dbn='test_db')
        th.create_token(keys={'test_suite':'test_delete_tokens','lock':1}, append="Tokentest", attach=[])
        th.add_status_views()
        self.assertTrue(len(th.list_tokens_from_view('locked'))==1)
        self.assertTrue(len(th.list_tokens_from_view('todo'))==0)
        th.add_view('to_reset_view',cond=' doc.test_suite == "test_delete_token" ' )
        th.reset_tokens('to_reset_view')
        self.assertTrue(len(th.list_tokens_from_view('todo'))==1)
        self.assertTrue(len(th.list_tokens_from_view('locked'))==0)
        th.delete_tokens('to_reset_view')
        self.assertTrue(len(th.list_tokens_from_view('todo'))==0)
        th.del_view('to_reset_view')
        th.purge_tokens()

    def test_purge_tokens(self):
        T_TYPE = ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(5))
        th = Token.Token_Handler(t_type=T_TYPE, srv="http://localhost:5984/",
                                 uname="", pwd="", dbn='test_db')
        th.create_token(keys={'test_suite':'Token','lock':1}, append="Tokentest", attach=[])
        pc=picas_cred()
        pc.user,pc.password="",""
        pc.database = 'test_db'
        Token.purge_tokens(T_TYPE,pc, "http://localhost:5984/")
