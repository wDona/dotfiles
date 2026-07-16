#!/usr/bin/env bash
# Fecha/hora en espanol para waybar (sin depender del locale del sistema).
dias=(Dom Lun Mar Mie Jue Vie Sab)
meses=(Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic)
dow=$(date +%w)            # 0=domingo
d=$(date +%-d)
m=$(date +%-m)
hm=$(date +%H:%M)
echo "󰥔 ${dias[$dow]} $d ${meses[$((m - 1))]}, $hm"
