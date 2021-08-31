__version__ = '0.0.1'

from setuptools import setup


setup(
    name='oca',
    version=__version__,
    author='Trobz',
    author_email='contact@trobz.com',
    url='https://trobz.com',
    description='OCA helpers',
    install_requires=[
        'manifestoo',
        'pre-commit'
    ],
    scripts=[
        'oca.sh',
        'cloc-odoo.py'
    ],
    classifiers=[
        'Programming Language :: Shell',
        'Intended Audience :: Developers',
        'Environment :: Console']
)
