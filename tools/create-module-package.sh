#!/bin/bash
mkdir dist/
echo "Creating package..."
tar -czf dist/perl-Program.tar.gz ./* --exclude="dist/" --exclude="tools/"
echo "Done"