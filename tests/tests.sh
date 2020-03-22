#!bin/bash
TIME_FC=time.sh
ONE_CORE=one_core.sh
CORE_NUM=0
FILE=data.dat

#make

echo "#" > $FILE
cat $FILE
a=-0.5
for i in $(ls *.out)
do
    total=0
    for _ in {1..100}
    do
        val=$((bash $ONE_CORE $CORE_NUM bash $TIME_FC $i) 2>&1 | tr -d '\n')
        total=$(echo "scale=8; $total + $val" | bc)
    done
    avg=$(echo "scale=8; $total / 100" | bc)
    a=$(echo "scale=3; $a + 0.5" | bc)
    echo $a | awk '{printf "%.3f ", $1}'
    printf $i | sed "s/\.out/ /g" | sed "s/.*\///g"
    echo $avg | awk '{printf "%f\n", $0}'
    
    echo $a | awk '{printf "%.3f ", $1}' >> $FILE
    printf $i | sed "s/\.out/ /g" | sed "s/.*\///g" >> $FILE
    echo $avg | awk '{printf "%f\n", $0}' >> $FILE
done 

