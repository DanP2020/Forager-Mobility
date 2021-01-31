extensions [ gis ]

undirected-link-breed [ associations association ]

breed [ camps camp ]
breed [ sites site ]

globals [ topography biomes day month year climate sealevelmod campidcounter seasonalgrowth ]

associations-own [ strength persistence ]

camps-own [ target patch-list population forage-efficiency energy energy-req energy-max propagation-counter friendly-groups adversarial-groups material-remains ]

patches-own [ elevation envirotype mmax mresource tmax tresource biome-code biome record ]

to go
  acquire
  consume
  movement
  update
  tick
end

to update
  update-calendar
  update-patch-color
  deposit
end

to deposit
  ask camps
  [ let tmpremains material-remains
    ask patch-here
    [ set record lput tmpremains record ]
    set material-remains "none" ]
end

to acquire
  ask camps
  [ if energy < energy-max
    [ let currentforage (population * forage-efficiency * round(random-normal 2250 250) )
      let tmpforage 0
      let tmptype "none"
      while [ any? patches in-radius 10 with [ tresource > 0 or mresource > 0 ] and tmpforage < currentforage ]
      [ ask one-of patches in-radius 10 with [ tresource > 0 or mresource > 0 ]
        [ if tresource > 0
          [ ifelse tresource > (currentforage - tmpforage)
            [ set tmpforage tmpforage + (currentforage - tmpforage)
              set tresource tresource - (currentforage - tmpforage) ]
            [ set tmpforage tmpforage + tresource
              set tresource 0 ]
            if tmptype = "none" [ set tmptype "t" ]
            if tmptype = "m" [ set tmptype "t m" ] ]
          if mresource > 0
          [ ifelse mresource > (currentforage - tmpforage)
            [ set tmpforage tmpforage + (currentforage - tmpforage)
              set mresource mresource - (currentforage - tmpforage) ]
            [ set tmpforage tmpforage + mresource
              set mresource 0 ]
            if tmptype = "none" [ set tmptype "m" ]
            if tmptype = "t" [ set tmptype "t m" ] ] ] ]
      set energy energy + tmpforage
      set material-remains tmptype ] ]

end

to consume
  ask camps
  [ ifelse energy > energy-req
    [ set energy energy - energy-req
      set propagation-counter propagation-counter + 1 ]
    [ set energy 0
      set population population - 1
      set energy-req population * round(random-normal 2000 250)
      set energy-max energy-req * 4
      set energy energy-req * 2
      if propagation-counter > 0 [ set propagation-counter propagation-counter - 1 ] ]
    if population < 5 [ die ] ]
end


to movement
  ask camps
  [ avoidance-affiliation
    associate
    move ]

  interact

end

to assess-value
  let tmpvalue sum [ tresource ] of patches in-radius 10
  if any? patches in-radius 20 with [ sum [ tresource ] of patches in-radius 10 > tmpvalue ]
  [ if random 100 < 50
    [ set target one-of patches in-radius 20 with [ sum [ tresource ] of patches in-radius 10 > tmpvalue ] ] ]
end

to associate
  if any? other camps in-radius 10
  [ create-associations-with other camps in-radius 10
      [ set strength 0
        set persistence 100 ] ]
end

to interact
  ask associations
  [ ifelse link-length < 10
    [ if strength > -1 or strength < 1
      [ let interaction one-of [ 0.01 -0.01 0 ]
        if interaction = 0.01
        [ if strength < 1 [ set strength strength + interaction ] ]
        if interaction = -0.01
        [ if strength > -1 [ set strength strength + interaction ] ] ]
        set persistence persistence + 10 ]
    [ set persistence persistence - 1
      if persistence <= 0 [ if random 100 < 50 [ die ] ] ] ]
end

to avoidance-affiliation
  set friendly-groups [ ]
  set adversarial-groups [ ]

  if any? my-associations with [ strength > 0 ]
  [ let tmplist [ ]
    ask my-associations with [ strength > 0 ] [ set tmplist lput other-end tmplist ]
    set friendly-groups tmplist ]
  if any? my-associations with [ strength < 0 ]
  [ let tmplist [ ]
    ask my-associations with [ strength < 0 ] [ set tmplist lput other-end tmplist ]
    set adversarial-groups tmplist ]

  let chance 10
  let tmpfriendly friendly-groups
  let tmpadversary adversarial-groups

  if social-priority = "affiliation"
  [ while [ chance > 0 ]
    [ assess-value
      ask target
      [ ifelse member? camps in-radius 10 tmpfriendly and not member? camps in-radius chance tmpadversary
        [ set chance 0 ]
        [ set chance chance - 1 ] ] ] ]


  if social-priority = "avoidance"
  [ while [ chance > 0 ]
    [ assess-value
      ask target
      [ ifelse member? camps in-radius chance tmpfriendly and not member? camps in-radius 10 tmpadversary
        [ set chance 0 ]
        [ set chance chance - 1 ] ] ] ]

  if social-priority = "none"
  [ while [ chance > 0 ]
    [ assess-value
      ask target
      [ ifelse member? camps in-radius chance tmpfriendly and not member? camps in-radius chance tmpadversary
        [ set chance 0 ]
        [ set chance chance - 1 ] ] ] ]
end

to move
  move-to target
end

to populate
  create-camps starting-camps
  [ set campidcounter campidcounter + 1
    set shape "triangle"
    set size 5
    set population round (random-normal 25 5)
    set energy-req population * round(random-normal 2000 250)
    set energy-max energy-req * 4
    set energy energy-req * 2
    set forage-efficiency one-of [ 0.8 0.9 1 1.1 1.2 ]
    set propagation-counter 0
    set patch-list [ ]
    set friendly-groups [ ]
    set adversarial-groups [ ]
    set material-remains "none" ]

  ask camps
  [ move-to one-of patches with [ (envirotype = "coastal" or envirotype = "terrestrial") and (elevation <= 200) ]
    set target patch-here ]
end

to propagate
  ask camps
  [ if propagation-counter > 100
    [ if random 100 > 25
      [ set population population + round(random-normal 3 1)
        set energy-req population * round(random-normal 2000 250)
        set energy-max energy-req * 4
        set energy energy-req * 2
        set propagation-counter 0 ] ]

    if population >= 50
    [ if random 100 > 50
      [ let tmppop population
        hatch-camps 1
        [ set population round(tmppop / 2)
          set population population + round(random-normal 3 1)
          set energy-req population * round(random-normal 2000 250)
          set energy-max energy-req * 4
          set energy energy-req * 2
          set propagation-counter 0 ] ] ] ]
end

to dessicate
  ask patches with [ tresource > 0 ]
  [ if random-float 1 < .1
    [ set tresource tresource - 200 ] ]
end

to regrow
  let tmpcount 0
  let regrowth-coeff 0

  set tmpcount count patches with [ biome = "forest" ]
  set regrowth-coeff 0.8
  ask patches with [ biome = "forest" and tresource > 0 ]
  [ if tresource < tmax
    [ set tresource tresource + random(regrowth-coeff * 10) ] ]
  let tmpforest (count patches with [ biome = "forest" and tresource > 0 ] )
  if tmpforest < (tmpcount * resource-density)
  [ let tmpgrowth random((tmpcount * resource-density) - tmpforest)
    if tmpgrowth < count patches with [ biome = "forest" and tresource = 0 ]
    [ ask n-of tmpgrowth patches with [ biome = "forest" and tresource = 0 ]
      [ set mmax 0
        set tmax random 80000
        set tresource random(regrowth-coeff * 1000) ] ] ]

  set tmpcount count patches with [ biome = "fynbos" ]
  set regrowth-coeff 0.6
  ask patches with [ biome = "fynbos" and tresource > 0 ]
  [ if tresource < tmax
    [ set tresource tresource + random(regrowth-coeff * 10) ] ]
  let tmpfynbos (count patches with [ biome = "fynbos" and tresource > 0 ] )
  if tmpfynbos < (tmpcount * resource-density)
  [ let tmpgrowth random((tmpcount * resource-density) - tmpfynbos)
    if tmpgrowth < count patches with [ biome = "fynbos" and tresource = 0 ]
    [ ask n-of tmpgrowth patches with [ biome = "fynbos" and tresource = 0 ]
      [ set mmax 0
        set tmax random 60000
        set tresource random(regrowth-coeff * 1000) ] ] ]

  set tmpcount count patches with [ biome = "grassland" ]
  set regrowth-coeff 0.4
  ask patches with [ biome = "grassland" and tresource > 0 ]
  [ if tresource < tmax
    [ set tresource tresource + random(regrowth-coeff * 10) ] ]
  let tmpgrassland (count patches with [ biome = "grassland" and tresource > 0 ] )
  if tmpgrassland < (tmpcount * resource-density)
  [ let tmpgrowth random((tmpcount * resource-density) - tmpgrassland)
    if tmpgrowth < count patches with [ biome = "grassland" and tresource = 0 ]
    [ ask n-of tmpgrowth patches with [ biome = "grassland" and tresource = 0 ]
      [ set mmax 0
        set tmax random 40000
        set tresource random(regrowth-coeff * 1000) ] ] ]

  set tmpcount count patches with [ biome = "nama karoo" ]
  set regrowth-coeff 0.3
  ask patches with [ biome = "nama karoo" and tresource > 0 ]
  [ if tresource < tmax
    [ set tresource tresource + random(regrowth-coeff * 10) ] ]
  let tmpnamakaroo (count patches with [ biome = "nama karoo" and tresource > 0 ] )
  if tmpnamakaroo < (tmpcount * resource-density)
  [ let tmpgrowth random((tmpcount * resource-density) - tmpnamakaroo)
    if tmpgrowth < count patches with [ biome = "nama karoo" and tresource = 0 ]
    [ ask n-of tmpgrowth patches with [ biome = "nama karoo" and tresource = 0 ]
      [ set mmax 0
        set tmax random 30000
        set tresource random(regrowth-coeff * 1000) ] ] ]

  set tmpcount count patches with [ biome = "savanna" ]
  set regrowth-coeff 0.4
  ask patches with [ biome = "savanna" and tresource > 0 ]
  [ if tresource < tmax
    [ set tresource tresource + random(regrowth-coeff * 10) ] ]
  let tmpsavanna (count patches with [ biome = "savanna" and tresource > 0 ] )
  if tmpsavanna < (tmpcount * resource-density)
  [ let tmpgrowth random((tmpcount * resource-density) - tmpsavanna)
    if tmpgrowth < count patches with [ biome = "savanna" and tresource = 0 ]
    [ ask n-of tmpgrowth patches with [ biome = "savanna" and tresource = 0 ]
    [ set mmax 0
      set tmax random 40000
        set tresource random(regrowth-coeff * 1000) ] ] ]

  set tmpcount count patches with [ biome = "succulent karoo" and tresource > 0 ]
  set regrowth-coeff 0.3
  ask patches with [ biome = "succulent karoo" and tresource > 0 ]
  [ if tresource < tmax
    [ set tresource tresource + random(regrowth-coeff * 10) ] ]
  let tmpsucculentkaroo (count patches with [ biome = "succulent karoo" and tresource > 0 ] )
  if tmpsucculentkaroo < (tmpcount * resource-density)
  [ let tmpgrowth random((tmpcount * resource-density) - tmpsucculentkaroo)
    if tmpgrowth < count patches with [ biome = "succulent karoo" and tresource = 0 ]
    [ ask n-of tmpgrowth patches with [ biome = "succulent karoo" and tresource = 0 ]
      [ set mmax 0
        set tmax random 30000
        set tresource random(regrowth-coeff * 1000) ] ] ]

  set tmpcount count patches with [ biome = "thicket" ]
  set regrowth-coeff 0.6
  ask patches with [ biome = "thicket" and tresource > 0 ]
  [ if tresource < tmax
    [ set tresource tresource + random(regrowth-coeff * 10) ] ]
  let tmpthicket (count patches with [ biome = "thicket" and tresource > 0 ] )
  if tmpthicket < (tmpcount * resource-density)
  [ let tmpgrowth random((tmpcount * resource-density) - tmpthicket)
    if tmpgrowth < count patches with [ biome = "thicket" and tresource = 0 ]
    [ ask n-of tmpgrowth patches with [ biome = "thicket" and tresource = 0 ]
      [ set mmax 0
        set tmax random 60000
        set tresource random(regrowth-coeff * 1000) ] ] ]

  set tmpcount count patches with [ biome = "desert" ]
  set regrowth-coeff 0.2
  ask patches with [ biome = "desert" and tresource > 0 ]
  [ if tresource < tmax
    [ set tresource tresource + random(regrowth-coeff * 10) ] ]
  let tmpdesert (count patches with [ biome = "desert" and tresource > 0 ] )
  if tmpdesert < (tmpcount * resource-density)
  [ let tmpgrowth random((tmpcount * resource-density) - tmpdesert)
    if tmpgrowth < count patches with [ biome = "desert" and tresource = 0 ]
    [ ask n-of tmpgrowth patches with [ biome = "desert" and tresource = 0 ]
      [ set mmax 0
        set tmax random 20000
        set tresource random(regrowth-coeff * 1000) ] ] ]

  set tmpcount count patches with [ biome = "ocean" ]
  set regrowth-coeff 1
  ask patches with [ biome = "ocean" and envirotype = "coastal" and mresource > 0 ]
  [ if mresource < mmax
    [ set mresource mresource + random(regrowth-coeff * 10) ] ]
  let tmpocean (count patches with [ biome = "ocean" and envirotype = "coastal" and mresource > 0 ] )
  if tmpocean < (tmpcount * resource-density)
  [ let tmpgrowth random((tmpcount * resource-density) - tmpocean)
    if tmpgrowth < count patches with [ biome = "ocean" and envirotype = "coastal" and mresource = 0 ]
    [ ask n-of tmpgrowth patches with [ biome = "ocean" and envirotype = "coastal" and mresource = 0 ]
      [ set tmax 0
        set mmax random 100000
        set mresource random(regrowth-coeff * 1000) ] ] ]

end

to update-patch-color
  if color-by = "elevation"
  [ ask patches with [ elevation >= (0 + sealevelmod) ] [ set pcolor scale-color green elevation -500 2500 ]
    ask patches with [ elevation < (0 + sealevelmod) ] [ set pcolor scale-color blue elevation -5500 2000 ] ]

  if color-by = "elevation and coastal"
  [ ask patches with [ elevation >= (10 + sealevelmod) ] [ set pcolor scale-color green elevation -500 2500 ]
    ask patches with [ elevation < (-10 + sealevelmod) ] [ set pcolor scale-color blue elevation -5500 2000 ]
    ask patches with [ elevation > (-10 + sealevelmod) and elevation <= (10 + sealevelmod) ] [ set pcolor scale-color red elevation -100 100 ] ]

  if color-by = "subsistence resource patches"
  [ ask patches with [ elevation >= (0 + sealevelmod) ] [ set pcolor scale-color gray elevation -500 2500 ]
    ask patches with [ elevation < (0 + sealevelmod) ] [ set pcolor scale-color gray elevation -5500 2000 ]
    ask patches with [ mresource > 0 ]
    [ set pcolor scale-color blue mresource 0 100000]
    ask patches with [ tresource > 0 ]
    [ set pcolor scale-color green tresource 0 100000] ]

  if color-by = "envirotype"
  [ ask patches with [ envirotype = "mountain" ] [ set pcolor orange ]
    ask patches with [ envirotype = "terrestrial" ] [ set pcolor green ]
    ask patches with [ envirotype = "coastal" ] [ set pcolor brown ]
    ask patches with [ envirotype = "marine" ] [ set pcolor blue ]
    ask patches with [ envirotype = "desert" ] [ set pcolor brown - 4 ] ]

    if color-by = "biome"
  [ ask patches
    [ if biome-code = 1 [ set pcolor green ]
      if biome-code = 2 [ set pcolor green + 4 ]
      if biome-code = 3 [ set pcolor green + 2 ]
      if biome-code = 4 [ set pcolor brown + 2 ]
      if biome-code = 5 [ set pcolor green - 4 ]
      if biome-code = 6 [ set pcolor brown - 2 ]
      if biome-code = 7 [ set pcolor green + 6 ]
      if biome-code = 8 [ set pcolor brown ]
      if biome-code = 9 [ set pcolor blue ] ] ]
end

to update-envirotypes
  ask patches with [ elevation > ( 2 + sealevelmod ) and envirotype = "coastal"]
  [ set envirotype "terrestrial"
    set mresource 0
    set biome-code one-of [ 1 2 7 ]
    if biome-code = 1 [ set biome "forest" set mmax 0 set mresource 0 set tmax random 80000 ]
    if biome-code = 2 [ set biome "fynbos" set mmax 0 set mresource 0 set tmax random 60000 ]
    if biome-code = 7 [ set biome "thicket" set mmax 0 set mresource 0 set tmax random 60000 ] ]
  ask patches with [ elevation <= ( -2 + sealevelmod ) and envirotype = "coastal" ]
  [ set envirotype "marine"
    set biome-code 9
    set biome "ocean"
    set tmax 0
    set tresource 0
    set mmax 0
    set mresource 0 ]
  ask patches with [ elevation > ( 2 + sealevelmod ) and elevation <= ( -2 + sealevelmod ) and (envirotype = "marine" or envirotype = "terrestrial")]
  [ set envirotype "coastal"
    set biome-code 9
    set biome "ocean"
    set tmax 0
    set tresource 0
    set mmax random 100000 ]
end

to update-environment
  update-sealevel
  update-envirotypes
end

to update-sealevel
  let chance random 100
  if climate = "warming" and sealevelmod <= 50 [ set sealevelmod sealevelmod + 1 ]
  if climate = "cooling" and sealevelmod >= -100 [ set sealevelmod sealevelmod - 1 ]
  if chance < 5
  [ if climate = "warming" [ set climate one-of [ "warming" "cooling" "stable" ] ]
    if climate = "cooling" [ set climate one-of [ "warming" "cooling" "stable" ] ] ]
  if climate = "stable" and random 100 < 25 [ set climate one-of [ "warming" "cooling" "stable" ] ]
  update-patch-color
end

to update-calendar
  if month = "dec" [ ifelse day < 31 [ set day day + 1 regrow] [ set day 1 set month "jan" set year year + 1] ]
  if month = "nov" [ ifelse day < 30 [ set day day + 1 regrow] [ set day 1 set month "dec" ] ]
  if month = "oct" [ ifelse day < 31 [ set day day + 1 regrow] [ set day 1 set month "nov" ] ]
  if month = "sep" [ ifelse day < 30 [ set day day + 1 ] [ set day 1 set month "oct" ] ]
  if month = "aug" [ ifelse day < 31 [ set day day + 1 dessicate] [ set day 1 set month "sep" ] ]
  if month = "jul" [ ifelse day < 31 [ set day day + 1 dessicate] [ set day 1 set month "aug" ] ]
  if month = "jun" [ ifelse day < 30 [ set day day + 1 dessicate] [ set day 1 set month "jul" ] ]
  if month = "may" [ ifelse day < 31 [ set day day + 1 dessicate] [ set day 1 set month "jun" update-environment ] ]
  if month = "apr" [ ifelse day < 30 [ set day day + 1 dessicate] [ set day 1 set month "may" ] ]
  if month = "mar" [ ifelse day < 31 [ set day day + 1 ] [ set day 1 set month "apr" propagate ] ]
  if month = "feb" [ ifelse day < 28 [ set day day + 1 regrow] [ set day 1 set month "mar" ] ]
  if month = "jan" [ ifelse day < 31 [ set day day + 1 regrow] [ set day 1 set month "feb" ] ]
end

to update-biomes
  let tmpcount 0

  ask patches with [ biome-code = 1 ]
  [ set biome "forest"
    set envirotype "terrestrial" ]
  set tmpcount count patches with [ biome = "forest" ]
  ask n-of (round(tmpcount * resource-density)) patches with [ biome = "forest" ]
  [ set mmax 0
    set tmax random 80000
    set tresource random tmax ]

  ask patches with [ biome-code = 2 ]
  [ set biome "fynbos"
    set envirotype "terrestrial" ]
  set tmpcount count patches with [ biome = "fynbos" ]
  ask n-of (round(tmpcount * resource-density)) patches with [ biome = "fynbos" ]
  [ set mmax 0
    set tmax random 60000
    set tresource random tmax ]

  ask patches with [ biome-code = 3 ]
  [ set biome "grassland"
    set envirotype "terrestrial" ]
  set tmpcount count patches with [ biome = "grassland" ]
  ask n-of (round(tmpcount * resource-density)) patches with [ biome = "grassland" ]
  [ set mmax 0
    set tmax random 40000
    set tresource random tmax ]

  ask patches with [ biome-code = 4 ]
  [ set biome "nama karoo"
    set envirotype "terrestrial" ]
  set tmpcount count patches with [ biome = "nama karoo" ]
  ask n-of (round(tmpcount * resource-density)) patches with [ biome = "nama karoo" ]
  [ set mmax 0
    set tmax random 30000
    set tresource random tmax ]

  ask patches with [ biome-code = 5 ]
  [ set biome "savanna"
    set envirotype "terrestrial" ]
  set tmpcount count patches with [ biome = "savanna" ]
  ask n-of (round(tmpcount * resource-density)) patches with [ biome = "savanna" ]
  [ set mmax 0
    set tmax random 40000
    set tresource random tmax ]

  ask patches with [ biome-code = 6 ]
  [ set biome "succulent karoo"
    set envirotype "terrestrial" ]
  set tmpcount count patches with [ biome = "succulent karoo" ]
  ask n-of (round(tmpcount * resource-density)) patches with [ biome = "succulent karoo" ]
  [ set mmax 0
    set tmax random 30000
    set tresource random tmax ]

  ask patches with [ biome-code = 7 ]
  [ set biome "thicket"
    set envirotype "terrestrial" ]
  set tmpcount count patches with [ biome = "thicket" ]
  ask n-of (round(tmpcount * resource-density)) patches with [ biome = "thicket" ]
  [ set mmax 0
    set tmax random 60000
    set tresource random tmax ]

  ask patches with [ biome-code = 8 ]
  [ set biome "desert"
    set envirotype "terrestrial" ]
  set tmpcount count patches with [ biome = "desert" ]
  ask n-of (round(tmpcount * resource-density)) patches with [ biome = "desert" ]
  [ set mmax 0
    set tmax random 20000
    set tresource random tmax ]

  ask patches with [ biome-code = 9 ]
  [ set biome "ocean"
    set envirotype "marine"]

  ask patches with [ elevation > -2 and elevation <= 2 ]
  [ if any? neighbors with [ biome-code != 9 ]
    [ set envirotype "coastal"
      set mmax random 100000
      set mresource random mmax
      set tmax 0
      set tresource 0 ] ]
end
to setup
  clear-all
  reset-ticks
  set topography gis:load-dataset "toporaster.asc"
  set biomes gis:load-dataset "sabiomeraster1.asc"

  gis:set-world-envelope gis:envelope-of topography
  gis:apply-raster topography elevation
  gis:apply-raster biomes biome-code

  ask patches with [ pycor = min-pycor ] [ set elevation -3000 ]

  set climate one-of [ "warming" "cooling" "stable" ]
  set sealevelmod 0

  set day 1
  set month "jan"
  set year 1

  update-biomes
  update-patch-color

  set campidcounter 1
  populate

  ask patches [ set record [ ] ]

  stop-inspecting-dead-agents
  inspect one-of camps
  inspect patch 123 135
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
954
755
-1
-1
1.75
1
10
1
1
1
0
0
0
1
0
420
0
420
1
1
1
ticks
30.0

BUTTON
8
10
72
43
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
76
10
139
43
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
963
10
1020
55
Month
month
17
1
11

MONITOR
1027
10
1084
55
Day
day
17
1
11

MONITOR
1091
10
1148
55
Year
year
17
1
11

MONITOR
963
63
1029
108
Sea Level
sealevelmod
17
1
11

MONITOR
1037
63
1101
108
Climate
climate
17
1
11

CHOOSER
962
168
1174
213
color-by
color-by
"elevation" "biome" "envirotype" "elevation and coastal" "subsistence resource patches"
0

PLOT
963
232
1163
382
Climate Trend
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot sealevelmod"

MONITOR
962
115
1040
160
Terr Patches
count patches with [ tresource > 0 ]
17
1
11

MONITOR
1048
115
1141
160
Coast Patches
count patches with [ mresource > 0 ]
17
1
11

SLIDER
7
54
179
87
starting-camps
starting-camps
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
6
93
178
126
resource-density
resource-density
0
1
0.5
.1
1
NIL
HORIZONTAL

BUTTON
142
10
205
43
Step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
1107
63
1164
108
Camps
count camps
17
1
11

PLOT
969
411
1169
561
Resource Patches
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count patches with [tresource > 0 ]"

CHOOSER
7
135
145
180
social-priority
social-priority
"affiliation" "avoidance" "none"
0

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="color-by">
      <value value="&quot;elevation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-priority">
      <value value="&quot;affiliation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="resource-density">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-camps">
      <value value="30"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
