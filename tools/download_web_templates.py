"""Fetch only the official single-threaded Web template using ZIP range reads."""
import io,json,urllib.request,zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
with urllib.request.urlopen('https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.2-stable') as response:
 asset=next(a for a in json.load(response)['assets'] if a['name']=='Godot_v4.7.2-stable_export_templates.tpz')
class RemoteZip(io.RawIOBase):
 def __init__(self):
  self.pos=0;self.length=asset['size'];self.url=asset['browser_download_url']
 def seekable(self):return True
 def readable(self):return True
 def tell(self):return self.pos
 def seek(self,offset,whence=0):
  self.pos=offset if whence==0 else (self.pos if whence==1 else self.length)+offset
  return self.pos
 def read(self,n=-1):
  if n<0:n=self.length-self.pos
  n=min(n,self.length-self.pos)
  if n<=0:return b''
  req=urllib.request.Request(self.url,headers={'Range':f'bytes={self.pos}-{self.pos+n-1}','User-Agent':'CoinGarden-WebExport'})
  with urllib.request.urlopen(req,timeout=120) as response:
   if response.status!=206:raise RuntimeError(f'Range request unsupported: {response.status}')
   data=response.read()
  if len(data)!=n:raise RuntimeError(f'Incorrect range size: {len(data)} != {n}')
  self.pos+=len(data);return data
with zipfile.ZipFile(RemoteZip()) as archive:
 names=[n for n in archive.namelist() if 'web' in n.lower()]
 print('Available:',names,flush=True)
 for name in names:
  if name.endswith('web_nothreads_release.zip'):
   data=archive.read(name)
   output=ROOT/'build/templates'/Path(name).name
   output.parent.mkdir(parents=True, exist_ok=True)
   output.write_bytes(data)
   print(output.name,len(data),flush=True)
