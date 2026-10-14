"""Regression checks for upstream features combined with the fork's behavior."""
import io,json,sqlite3,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'lib'))
from olook import cli,config,store

class UpstreamTests(unittest.TestCase):
 def test_stdin_keeps_dash_prefixed_search_as_data(self):
  query='--not-an-option private search fixture'
  stream=io.StringIO(json.dumps(['--json','search','--query',query])+'\n')
  with patch.object(sys,'stdin',stream),patch.object(cli,'cmd_search') as search:
   cli.main(['--argv-stdin'])
   self.assertEqual(search.call_args.args[0].query,query)
 def test_stdin_header_preserves_command_payload(self):
  stream=io.StringIO(json.dumps(['--json','auth','fixture','--password-stdin'])+'\nfixture-password\n')
  with patch.object(sys,'stdin',stream),patch.object(cli,'cmd_auth') as auth:
   cli.main(['--argv-stdin']);self.assertEqual(stream.read(),'fixture-password\n')
   self.assertTrue(auth.call_args.args[0].password_stdin)
 def test_preferences_persist_without_replacing_account_or_privacy_settings(self):
  with tempfile.TemporaryDirectory() as folder,patch.object(config,'CONFIG_PATH',Path(folder)/'accounts.json'),patch.object(config,'ensure_dirs'):
   config.CONFIG_PATH.write_text(json.dumps({'accounts':[{'id':'fixture'}],'imagePolicy':'never'}))
   config.set_body_view('plain');config.set_compose_format('markdown')
   self.assertEqual(config.body_view(),'plain');self.assertEqual(config.compose_format(),'markdown')
   self.assertEqual(config.load()['accounts'],[{'id':'fixture'}]);self.assertEqual(config.image_policy(),'never')
 def test_message_copies_remain_scoped_to_the_account(self):
  db=sqlite3.connect(':memory:');db.row_factory=sqlite3.Row
  db.execute('create table messages(account text,folder text,uid integer,message_id text)')
  db.executemany('insert into messages values(?,?,?,?)',[('a','INBOX',1,'same'),('a','All',8,'same'),('b','All',9,'same'),('a','Trash',3,'other')])
  self.assertEqual(store.copies_elsewhere(db,'a','INBOX',[1]),{'All':[8]})
  self.assertEqual(store.message_ids_in(db,'a',['Trash']),{'other'})
  db.close()
if __name__=='__main__':unittest.main()
