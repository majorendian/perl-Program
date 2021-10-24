#!/bin/bash
mkdir ../dist/
rm ../dist/perl-Program.tgz
echo "Creating package..."
tar -czf ../dist/perl-Program.tar.gz ../* --exclude="../dist/" --exclude="../tools/"
echo "Done"