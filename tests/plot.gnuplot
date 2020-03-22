set terminal svg size 550, 760
set output 'graph.svg'

set boxwidth 0.40
set style fill solid

set ylabel 'Porovnání algoritmu PSO (40 částic)'

set xtic rotate by 90 scale 0
set xtic offset 0, -6
set bmargin 7
unset ytics
set y2tics rotate by 90
set y2tics offset 0, -1.5
set y2label 't [s]' offset -2.5
unset key
set y2tic offset 0,-0.5
set yrange[0:2.8]
set offset graph 0, 0, 0.0001, 0

plot "data.dat" using 1:3:xtic(2) with boxes

set terminal x11
set output
replot
pause -1
