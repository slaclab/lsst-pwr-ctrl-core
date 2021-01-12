
from distutils.core import setup
from git import Repo

repo = Repo()

# Get version before adding version file
ver = repo.git.describe('--tags')

# append version constant to package init
with open('python/LsstPwrCtrlCore/__init__.py','a') as vf:
    vf.write(f'\n__version__="{ver}"\n')

setup (
   name='lsst_pwr_ctrl_core',
   version=ver,
   packages=['LsstPwrCtrlCore', ],
   package_dir={'':'python'},
)
