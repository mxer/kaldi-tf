#!/bin/bash

# Josh Meyer // jrmeyer.github.io

#
# this script should take in an ark file in txt form and return an arkfile
# in txt form



# given the name of the experiment, this script assumes file structure
# that I've got set up
exp_name=${1}
path_to_exp="/home/ubuntu/kaldi/egs/multi-task-kaldi/mtk/MTL/exp/${exp_name}/nnet3/egs"



if [ 1 ]; then
    echo "### CONVERTING BINARY EGS TO TEXT ###"
    echo "LOOKING FOR EGS IN ${path_to_exp}"
    # binary --> text
    KALDI=/home/ubuntu/kaldi/src/nnet3bin/nnet3-copy-egs
    $KALDI ark:${path_to_exp}/egs.1.ark ark,t:org-txt-ark
fi

if [ 1 ]; then
    echo "### CONVERT EGS TO TFRECORDS  ###"
    # EGS --> CSV
    python3 egs-to-csv.py org-txt-ark ark.csv
    # Split data into train / eval / all
    # I know this isn't kosher, but right
    # now idc about eval, it's just a step
    # in the scripts
    cp ark.csv all.csv
    mv ark.csv train.csv
    tail -n100 all.csv > eval.csv
    # CSV --> TFRECORDS
    python3 csv-to-tfrecords.py all.csv all.tfrecords
    python3 csv-to-tfrecords.py eval.csv eval.tfrecords
    python3 csv-to-tfrecords.py train.csv train.tfrecords
    # TRAIN K-MEANS

    time python3 train_and_eval.py     ## returns tf-labels.txt
    
fi

# VOTE FOR MAPPINGS
if [ 1 ]; then
    echo "### PERFORM MAPPING AND SAVE TO mod-txt-ark ###"
    cut -d' ' -f1 all.csv > kaldi-labels.txt
    paste -d' ' kaldi-labels.txt tf-labels.txt > combined-labels.txt
    python3 vote.py combined-labels.txt > mapping.txt
    python3 format-mapping.py mapping.txt formatted-mapping.txt
    # PERFORM MAPPING
    ./faster-mapping.sh org-txt-ark formatted-mapping.txt `cat DIM` #DIM is a file generated by egs-to-csv.py
    cat ARK_split* > mod-txt-ark
fi


if [ 1 ]; then
    echo "TXT.egs --> BIN.egs ;; RENAME AND MOVE BIN.egs"  
    # text --> binary
    $KALDI ark,t:mod-txt-ark ark,scp:egs.1.ark,egs.scp
    # fix paths
    sed -Ei 's/ egs/ MTL\/exp\/${exp_name}\/nnet3\/egs\/egs/g' egs.scp
    # move new egs to MTL dir
    mv egs.1.ark ${path_to_exp}/egs.1.ark-mod
    mv egs.scp ${path_to_exp}/egs.scp-mod
    # rename orgiinal egs
    mv ${path_to_exp}/egs.1.ark ${path_to_exp}/egs.1.ark-org
    mv ${path_to_exp}/egs.scp ${path_to_exp}/egs.scp-org
    # make softlinks to new egs
    ln -s ${path_to_exp}/egs.1.ark-mod ${path_to_exp}/egs.1.ark
    ln -s ${path_to_exp}/egs.scp-mod ${path_to_exp}/egs.scp

    echo "### OLD ARKS RENAMED WITH -org"
    echo "### NEW ARKS names with -mod"
    echo "### FRESH SOFTLINKS TO MOD"
fi


rm *-txt-ark DIM org-txt-ark ARK_split* mapping.txt tf-labels.txt all.csv kaldi-labels.txt combined-labels.txt eval.csv train.csv all.tfrecords eval.tfrecords train.tfrecords formatted-mapping.txt


