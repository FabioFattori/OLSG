#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -s <src>   (also: -src, --src)"
   echo -e "\t-src path to the source code"
   exit 1 # Exit script after printing help
}

while [ $# -gt 0 ]; do
   case "$1" in
      -s | -src | --src ) path="$2"; shift 2 ;;
    * ) helpFunction ;;
   esac
done

if [ -z "$path" ]
then
   echo "needs to provide the src path";
   helpFunction
fi