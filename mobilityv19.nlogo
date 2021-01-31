extensions [ gis csv profiler ]

breed [ camps camp ]
undirected-link-breed [ affiliations affiliaition ]

globals
[ ;; calendar variables for timekeeping and seasonality ( vegetation/shellfish)
  day
  month
  year

  ;; color lists for grouping
  colorlist
  uniquelist

  ;; raster variables for loading GIS data - elevation, biome data for vegetation, EVI data for varying seasonal vegetation
  topography
  biomes
  evi-mean-raster
  evi-sd-raster
  evi-counter           ;;variable for running total of days to match EVI seasonality shifts

  ;; resource management variables- kcal availability (biomes, shellfish patches) - loaded from CSV
  forest_resources
  fynbos_resources
  grassland_resources
  nama_karoo_resources
  savanna_resources
  succulent_karoo_resources
  thicket_resources
  desert_resources
  aeolianite_resources
  sandy_beach_resources
  boulders_resources
  rocky_headlands_resources
  wavecut_platforms_resources

  aeolianite_patches
  sandy_beach_patches
  boulders_patches
  rocky_headlands_patches
  wavecut_platforms_patches

  ;; sea level management variables - (change rate, timing, sea level modification)
  sealevel_timing_list
  sealevel_rate_list
  sealevel_sd_list
  sealevel_rate_counter
  sealevel_timing
  sealevel_rate
  sealevel_sd
  sealevel_counter
  sealevelmod

  marginal-check
  max-plantforage
  max-shellfishforage
  successful-hunts

  fertility-rate
  mortality-rate

  campwholist
  campstartlist
  campendlist
  campdistlist
  campcolorlist
  campmobilitylist
  camppoplist

  density-limit
]

patches-own
[ elevation                 ;; raster-loaded-value for meters above or below sea level
  envirotype                ;; trinary variable to keep track of terrestrial, coastal, and marine
  biome-code                ;; raster-loaded-value for one of seven biomes in South Africa - Forest, Fynbos, Grassland, Nama Karoo, Succulent Karoo, Savanna, Thicket
  biome                     ;; string value to label biome by code

  evi-current               ;; random value within normal distribution between EVI-mean and EVI-standard deviation that represents the patche's vegetation density
  evi-mean                  ;; raster-loaded value for pixel's seasonal EVI mean
  evi-sd                    ;; raster-loaded-value for pixel's seasonal EVI standard deviation

  plant-resources           ;; patch's vegetation resources (maximum possible forage per day)
  shellfish-resources       ;; patch's shellfish resources (maximum possible forage per day)
  hunting-chance-bushbok
  hunting-chance-bushpig
  hunting-chance-duiker
  hunting-chance-grysbok

  plant-record
  bone-record
  shell-record
  lithic-record
  oes-record
  ochre-record

  record
  record-length
  site-number ]          ;; probability of encountering game on patch

camps-own
[ initial-population-size
  population-size
  energy-required
  energy-consumption-possible
  proportion-of-requirement-met
  mobility-counter
  birth-counter
  death-counter
  held
  target
  starting-patch
  ending-patch
  distance-from-start ]

affiliations-own
  [ affinity
    persistence ]

;; ****************************Go Procedures*****************************
to go
  update-calendar
  agent-commands
  update-environment
  if year mod 100 = 0 and evi-counter = 1 [ update-record ]
  ifelse update_colors [ update-patch-color ] [ ]
  if year mod 100 = 0 and evi-counter = 1 [ export-world (word "results " year ".csv") ]
  ifelse year = 1000 [ sample-record stop ] [ ]
  tick
end

to-report forage-potential report plant-forage-potential + shellfish-forage-potential end
to-report plant-forage-potential report ( sum [ plant-resources ] of patches in-radius foraging-radius with [ plant-resources > 0 ]) end
to-report shellfish-forage-potential report ( sum [ shellfish-resources ] of patches in-radius foraging-radius with [ shellfish-resources > 0 ] ) end
to-report hunting-potential report  ( ( sum [ hunting-chance-bushbok ] of patches in-radius foraging-radius + sum [ hunting-chance-bushpig ] of patches in-radius foraging-radius + sum [ hunting-chance-duiker ] of patches in-radius foraging-radius + sum [ hunting-chance-grysbok ] of patches in-radius foraging-radius ) ) end

to agent-commands
  ask camps
  [ ;move-decision
    let my-forage patches in-radius foraging-radius with [ envirotype != "marine" ]
    set target one-of my-forage
    move-to target
    forage
    discard
    demographics
    ;social ]
  ]
end

to move-decision
  let move? "no"
  let my-forage patches in-radius foraging-radius
  let current-forage forage-potential
  if random-float 1 > ( current-forage / marginal-check) [ set move? "yes" ]
  if move? = "no" [
    let tmphunt max [ hunting-potential ] of my-forage
    if tmphunt > ( hunting-potential * 2 ) [ set move? "yes" ] ]
  if move? = "no" [ if proportion-of-requirement-met < 0.75 [ set move? "yes" ] ]
  if move? = "no"
  [ if any? other camps in-radius foraging-radius
    [ let avoidance? "no"
      if count my-links > 0
      [ ask my-links
        [ if avoidance? = "no"
          [ if affinity < -0.5 [ set avoidance? "yes" ] ] ]
        if avoidance? = "yes" [ if random 100 < 50 [ set move? "yes" ] ] ] ] ]
  ifelse move? = "yes" [ move ] [ ]
end

to move
  let current-forage forage-potential
  let maxmove round ( maximum-camp-movement / 5 )
  let focus-interaction nobody
  let focus-camp nobody

  ifelse any? other camps in-radius maxmove
  [ if count my-links > 0
    [ ask one-of my-links
      [ ifelse affinity > 0.5
        [ set focus-camp other-end set focus-interaction "positive" ]
        [ if affinity < -0.5 [ set focus-camp other-end set focus-interaction "negative" ] ] ] ] ]
  [ ]

  let maxmovepatches other patches in-radius maxmove with [ envirotype != "marine" ]
  let maxmoveforage maxmovepatches with [ forage-potential > current-forage ]
  ifelse focus-camp = nobody
  [ ifelse any? maxmoveforage
    [ set target one-of maxmoveforage ]
    [ set target one-of maxmovepatches ] ]
  [ let tmptarget nobody
    ask focus-camp [ set tmptarget patch-here ]
    ifelse [ forage-potential ] of tmptarget > current-forage
    [ set target tmptarget ]
    [ ifelse any? maxmoveforage
      [ set target one-of maxmoveforage  ]
      [ set target one-of maxmovepatches ] ] ]

  if target = nobody [ set target patch-here ]

  move-to target
  set mobility-counter mobility-counter + 1
end

to forage
  let forage-scaler random-normal 5 2.25

  let current-plant-forage patches in-radius foraging-radius with [ plant-resources > 0 ]
  let cpfs 0.001
  if sum [ plant-resources ] of current-plant-forage > 0
  [ set cpfs ( sum [ plant-resources ] of current-plant-forage ) ] ;current plant forage sum

  let current-shellfish-forage patches in-radius foraging-radius with [ shellfish-resources > 0 ]
  let csfs ( sum [ shellfish-resources ] of current-shellfish-forage ) ;current shellfish forage sum

  if random-float 1 < 0.01 [ set held [ ] set held lput one-of [ "lithic" "ochre" "oes" ] held ]
  let AGBcurve ( cpfs / ( cpfs + ( 0.2 * max-plantforage ) ) )
  let AGBcurveII AGBcurve * max-plantforage
  let camp-plant-pref (3 * cpfs ) / ( 3 * cpfs + 1 * csfs )

  let max-plant-consumption ( energy-consumption-possible * forage-scaler ) * camp-plant-pref
  let plant-consumption max-plant-consumption * AGBcurve
  if held != nobody [ if plant-consumption > 0 [ set held lput "plant" held ] ]

  let SFcurve csfs / ( csfs + ( 0.2 * max-shellfishforage ) )
  let SFcurveII SFcurve * max-shellfishforage
  let camp-shellfish-pref (3 * csfs ) / ( 3 * csfs + 1 * cpfs )

  let max-shellfish-consumption ( energy-consumption-possible * forage-scaler ) * camp-shellfish-pref
  let shellfish-consumption max-shellfish-consumption * SFcurve
  if held != nobody [ if shellfish-consumption > 0 [ set held lput "shell" held ] ]

  let new-plant-resources ( cpfs - plant-consumption )
  set new-plant-resources new-plant-resources / ( max-plantforage * count patches in-radius foraging-radius )
  let new-shellfish-resources ( csfs - shellfish-consumption )
  set new-shellfish-resources new-shellfish-resources / ( max-shellfishforage * count patches in-radius foraging-radius)

  let meat-yield 0
  let encounter nobody
  let success? random-float 1

  if random-float 1 < ( hunting-chance-bushbok * (population-size * 0.593346098 ) ) [ set encounter "bushbok" if success? < 0.07 [ set meat-yield 159750 ] ]
  if encounter = nobody and random-float 1 < ( hunting-chance-bushpig * (population-size * 0.593346098 ) ) [ set encounter "bushpig" if success? < 0.1 [ set meat-yield 76930 ] ]
  if encounter = nobody and random-float 1 < ( hunting-chance-duiker * (population-size * 0.593346098 ) ) [ set encounter "duiker" if success? < 0.5 [ set meat-yield 3450 ] ]
  if encounter = nobody and random-float 1 < ( hunting-chance-grysbok * (population-size * 0.593346098 ) ) [ set encounter "grysbok" if success? < 0.5 [ set meat-yield 3450 ] ]
  if meat-yield != 0 [ set successful-hunts successful-hunts + 1 set new-plant-resources new-plant-resources * 0.7 set new-shellfish-resources new-shellfish-resources * 0.7
    set meat-yield meat-yield - ( random (2000 - 500 + 1) + 500 )
    if held != nobody [ set held lput "bone" held ] ]

  ask patches in-radius foraging-radius [ set plant-resources precision ( plant-resources - (plant-resources * new-plant-resources) ) 5  ]
  ask patches in-radius foraging-radius [ set shellfish-resources precision ( shellfish-resources - ( shellfish-resources * new-shellfish-resources ) ) 5 ]

  set proportion-of-requirement-met (plant-consumption + shellfish-consumption + meat-yield) / energy-required
  discard
end

to discard
  if held != nobody
  [ set record lput one-of held record
    set record-length length record ]

  set held nobody
end

to update-record
  ask patches
  [ set plant-record lput ( length filter [ i -> i = "plant" ] record ) plant-record
    set bone-record lput ( length filter [ i -> i = "bone" ] record ) bone-record
    set shell-record lput ( length filter [ i -> i = "shell" ] record ) shell-record
    set lithic-record lput ( length filter [ i -> i = "lithic" ] record ) lithic-record
    set oes-record lput ( length filter [ i -> i = "oes" ] record ) oes-record
    set ochre-record lput ( length filter [ i -> i = "ochre" ] record ) ochre-record

    set record [ ] ]
end

to demographics
  let tmpfertility 0
  let tmpmortality 0

  ifelse sum [ population-size ] of camps <= ( 0.8 * density-limit )
  [ set tmpfertility ( fertility-rate / 1000 ) * population-size
    set tmpmortality ( mortality-rate / 1000 ) * population-size ]
  [ set tmpfertility ( fertility-rate / 10000 ) * population-size
    set tmpmortality ( mortality-rate / 1000 ) * population-size ]

  if proportion-of-requirement-met < 0.5
  [ set tmpfertility tmpfertility - ( tmpfertility * ( proportion-of-requirement-met / 0.5 ) )
    set tmpmortality tmpmortality + ( tmpmortality * ( proportion-of-requirement-met / 0.5 ) ) ]

  if random-float 100 < tmpfertility
  [ let tmpenergy energy-required / population-size
    set population-size population-size + 1
    set energy-required ( population-size * tmpenergy )
    set energy-consumption-possible ( energy-required * 1.5 )
    set birth-counter birth-counter + 1 ]

  if random-float 100 < tmpmortality
  [ let tmpenergy energy-required / population-size
    set population-size population-size - 1
    set energy-required ( population-size * tmpenergy )
    set energy-consumption-possible ( energy-required * 1.5 )
    set death-counter death-counter + 1 ]

  if random-float 1 < ( 1 / ( 1 + exp(1) ^ ( 0.5 * ( ( 47 ) - population-size ) ) ) )             ;logistic function: (1/(1+exp(1)^(k*(Y-x))))
  [ set initial-population-size ( round ( population-size / 2 ) )
    set population-size initial-population-size
    let tmpenergy energy-required / population-size
    set energy-required ( population-size * tmpenergy )
    set energy-consumption-possible ( energy-required * 1.5 )
    hatch-camps 1
    [ set birth-counter 0 ] ]

  if population-size < 10
  [ ifelse population-size < 5
    [ if random 100 < 50 [ die ] ]
    [ if random 100 < 25 [ die ] ] ]
end

;; ****************************Social Procedures*****************************

to social
  let colorcheck1 color
  associate
  ask my-affiliations
  [ interact
    dissociate
    if affinity > 0.5
    [ let colorcheck2 [ color ] of other-end
      if colorcheck1 != colorcheck2 [ group-up ] ] ]
  split
end

to associate
  if any? other camps in-radius 2
  [ create-affiliations-with other camps in-radius 2
    [ set affinity one-of [ 0.3 -0.3 ]
      set persistence (365 * 3) ] ]
end

to interact
  ifelse link-length < 2
  [ if affinity > -1 or affinity < 1
    [ let interaction one-of [ 0.01 -0.01 0 ]
      if interaction = 0.01
      [ if affinity < 1 [ set affinity affinity + interaction ] ]
      if interaction = -0.01
      [ if affinity > -1 [ set affinity affinity + interaction ] ] ]
    set persistence (365 * 3) ]
  [ ]
end

to dissociate
  ifelse link-length > 2
  [ set persistence persistence - 1 ]
  [ ]
  if persistence <= 0 [ die ]
end

to group-up
  if random-float 1 < affinity
  [ let endone one-of both-ends
    let endtwo one-of both-ends
    ask endone
    [ set endtwo other-end ]
    ask endone
    [ let colorcheck1 color
      let colorcheck2 color
      ask endtwo
      [ set colorcheck2 color ]
      ifelse count camps with [color = colorcheck1] > count camps with [color = colorcheck2]
      [ ask endtwo [ set color [color] of myself ] ]
      [ ask endtwo [ ask endone [ set color [color] of myself ] ] ] ] ]
  update-camp-color
end

to split
  let colorcheck color
  if not any? link-neighbors with [color != colorcheck] and count camps with [ color = colorcheck ] > 1
  [ let coloroptions [ 3 4 5 6 7 8 13 14 15 16 17 18 23 24 25 26 27 28 33 34 35 36 37 38 43 44 45 46 47 48 53 54 55 56 57
    58 63 64 65 66 67 68 73 74 75 76 77 78 83 84 85 86 87 88 93 94 95 96 97 98 103 104 105 106 107 108 113 114 115 116
    117 118 123 124 125 126 127 128 133 134 135 136 137 138 ]
    ask camps [ set coloroptions remove color coloroptions ]
    ifelse length coloroptions > 0
    [ if random 1000 < 1 [ set color one-of coloroptions ] ] [ ] ]
  update-camp-color
end

;; ****************************Environmental Procedures*****************************

to update-environment
  update-evi
  update-patch-attributes
  update-resources
end

to update-sealevel
  ifelse sealevel_counter = sealevel_timing
  [ set sealevel_rate_counter sealevel_rate_counter + 1
    set sealevel_timing item sealevel_rate_counter sealevel_timing_list
    set sealevel_rate item sealevel_rate_counter sealevel_rate_list
    set sealevelmod sealevelmod + sealevel_rate ]
  [ set sealevel_counter sealevel_counter + 1
    set sealevelmod sealevelmod + sealevel_rate ]
end

to update-patch-attributes
  let tmpradius 10

  let newland patches with [ ( elevation >= 0 + sealevelmod and envirotype = "marine" ) or ( elevation >= 0 + sealevelmod and evi-mean = -9999 ) ]
  if any? newland
  [ ask newland
    [ let mimic-choices patches in-radius tmpradius with [ envirotype = "terrestrial" and evi-mean > -9999 ]
      ifelse any? mimic-choices
      [ let mimic one-of mimic-choices
        set biome-code [ biome-code ] of mimic
        set biome [ biome ] of mimic
        set envirotype [ envirotype ] of mimic
        set evi-current [ evi-current ] of mimic
        set evi-mean [ evi-mean ] of mimic
        set evi-sd [ evi-sd ] of mimic ]
      [ let mimic one-of patches in-radius ( tmpradius * 5 ) with [ envirotype = "terrestrial" and evi-mean > -9999 ]
        set biome-code [ biome-code ] of mimic
        set biome [ biome ] of mimic
        set envirotype [ envirotype ] of mimic
        set evi-current [ evi-current ] of mimic
        set evi-mean [ evi-mean ] of mimic
        set evi-sd [ evi-sd ] of mimic ]
      if plant-resources < 0 [ set plant-resources 0 ] ] ]



  let newsea patches with [  elevation < 0 + sealevelmod and envirotype = "terrestrial" or ( elevation < 0 + sealevelmod and evi-mean > -9999 ) ]
  if any? newsea
  [ ask newsea
    [ let mimic-choices patches in-radius tmpradius with [ envirotype = "marine" and elevation = -9999 ]
      ifelse any? mimic-choices
      [ let mimic one-of mimic-choices
        set biome-code [ biome-code ] of mimic
        set biome [ biome ] of mimic
        set envirotype [ envirotype ] of mimic
        set evi-current [ evi-current ] of mimic
        set evi-mean [ evi-mean ] of mimic
        set evi-sd [ evi-sd ] of mimic ]
      [ let mimic one-of patches in-radius ( tmpradius * 5 ) with [ envirotype = "marine" ]
        set biome-code [ biome-code ] of mimic
        set biome [ biome ] of mimic
        set envirotype [ envirotype ] of mimic
        set evi-current [ evi-current ] of mimic
        set evi-mean [ evi-mean ] of mimic
        set evi-sd [ evi-sd ] of mimic ] ] ]

  ask patches with [ envirotype = "marine" and any? neighbors with [ envirotype = "terrestrial" ] ]
  [ let coastalneighbors neighbors with [ envirotype = "terrestrial" and ( ( elevation + sealevelmod ) > -20 and ( elevation + sealevelmod ) < 20 ) ]
    if any? coastalneighbors
    [ ask coastalneighbors
      [ set envirotype one-of [ "coastal-aeolianite" "coastal-sandybeach" "coastal-boulders" "coastal-rockyheadlands" "coastal-wavecutplatforms" ] ]
      set aeolianite_patches patches with [ envirotype = "coastal-aeolianite" ]
      set sandy_beach_patches patches with [ envirotype = "coastal-sandybeach" ]
      set boulders_patches patches with [ envirotype = "coastal-boulders" ]
      set rocky_headlands_patches patches with [ envirotype = "coastal-rockyheadlands" ]
      set wavecut_platforms_patches patches with [ envirotype = "coastal-wavecutplatforms" ] ] ]

  set density-limit ( count patches with [ envirotype != "marine" ] ) * 0.519375
end

to update-evi
  if ticks = 0 [ set evi-mean-raster gis:load-dataset "evi/evi_winter_mean.asc" gis:apply-raster evi-mean-raster evi-mean
                 set evi-sd-raster  gis:load-dataset "evi/evi_winter_sd.asc" gis:apply-raster evi-sd-raster evi-sd
                 ask patches [ ifelse evi-mean < 0 or evi-sd < 0 [ set evi-current 0 ] [ set evi-current random-normal evi-mean evi-sd ] ] ]

  if evi-counter = 81 [ set evi-mean-raster gis:load-dataset "evi/evi_spring_mean.asc" gis:apply-raster evi-mean-raster evi-mean
                       set evi-sd-raster  gis:load-dataset "evi/evi_spring_sd.asc" gis:apply-raster evi-sd-raster evi-sd
                       ask patches [ ifelse evi-mean < 0 or evi-sd < 0 [ set evi-current 0 ] [ set evi-current random-normal evi-mean evi-sd ] ] ]
  if evi-counter = 173 [ set evi-mean-raster gis:load-dataset "evi/evi_summer_mean.asc" gis:apply-raster evi-mean-raster evi-mean
                        set evi-sd-raster  gis:load-dataset "evi/evi_summer_sd.asc" gis:apply-raster evi-sd-raster evi-sd
                        ask patches [ ifelse evi-mean < 0 or evi-sd < 0 [ set evi-current 0 ] [ set evi-current random-normal evi-mean evi-sd ] ] ]
  if evi-counter = 265 [ set evi-mean-raster gis:load-dataset "evi/evi_autumn_mean.asc" gis:apply-raster evi-mean-raster evi-mean
                        set evi-sd-raster  gis:load-dataset "evi/evi_autumn_sd.asc" gis:apply-raster evi-sd-raster evi-sd
                        ask patches [ ifelse evi-mean < 0 or evi-sd < 0 [ set evi-current 0 ] [ set evi-current random-normal evi-mean evi-sd ] ] ]
  if evi-counter = 356 [ set evi-mean-raster gis:load-dataset "evi/evi_winter_mean.asc" gis:apply-raster evi-mean-raster evi-mean
                        set evi-sd-raster  gis:load-dataset "evi/evi_winter_sd.asc" gis:apply-raster evi-sd-raster evi-sd
                        ask patches [ ifelse evi-mean < 0 or evi-sd < 0 [ set evi-current 0 ] [ set evi-current random-normal evi-mean evi-sd ] ] ]
end

to update-resources
  if evi-counter = 81
  [ let evi-scaler max [ evi-current ] of patches
    ask patches with [ biome-code = 1 ] [ set plant-resources ( ( item 3 forest_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 2 ] [ set plant-resources ( ( item 3 fynbos_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 3 ] [ set plant-resources ( ( item 3 grassland_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 4 ] [ set plant-resources ( ( item 3 nama_karoo_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 5 ] [ set plant-resources ( ( item 3 savanna_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 6 ] [ set plant-resources ( ( item 3 succulent_karoo_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 7 ] [ set plant-resources ( ( item 3 thicket_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 8 ] [ set plant-resources ( ( item 3 desert_resources ) * ( evi-current / evi-scaler ) ) ]
    update-maxima ]

  if evi-counter = 173
  [ let evi-scaler max [ evi-current ] of patches
    ask patches with [ biome-code = 1 ] [ set plant-resources ( ( item 0 forest_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 2 ] [ set plant-resources ( ( item 0 fynbos_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 3 ] [ set plant-resources ( ( item 0 grassland_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 4 ] [ set plant-resources ( ( item 0 nama_karoo_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 5 ] [ set plant-resources ( ( item 0 savanna_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 6 ] [ set plant-resources ( ( item 0 succulent_karoo_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 7 ] [ set plant-resources ( ( item 0 thicket_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 8 ] [ set plant-resources ( ( item 0 desert_resources ) * ( evi-current / evi-scaler ) ) ]
    update-maxima ]

  if evi-counter = 265
  [ let evi-scaler max [ evi-current ] of patches
    ask patches with [ biome-code = 1 ] [ set plant-resources ( ( item 1 forest_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 2 ] [ set plant-resources ( ( item 1 fynbos_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 3 ] [ set plant-resources ( ( item 1 grassland_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 4 ] [ set plant-resources ( ( item 1 nama_karoo_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 5 ] [ set plant-resources ( ( item 1 savanna_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 6 ] [ set plant-resources ( ( item 1 succulent_karoo_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 7 ] [ set plant-resources ( ( item 1 thicket_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 8 ] [ set plant-resources ( ( item 1 desert_resources ) * ( evi-current / evi-scaler ) ) ]
    update-maxima ]

  if evi-counter = 356 or ticks = 0
  [ let evi-scaler max [ evi-current ] of patches
    ask patches with [ biome-code = 1 ] [ set plant-resources ( ( item 2 forest_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 2 ] [ set plant-resources ( ( item 2 fynbos_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 3 ] [ set plant-resources ( ( item 2 grassland_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 4 ] [ set plant-resources ( ( item 2 nama_karoo_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 5 ] [ set plant-resources ( ( item 2 savanna_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 6 ] [ set plant-resources ( ( item 2 succulent_karoo_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 7 ] [ set plant-resources ( ( item 2 thicket_resources ) * ( evi-current / evi-scaler ) ) ]
    ask patches with [ biome-code = 8 ] [ set plant-resources ( ( item 2 desert_resources ) * ( evi-current / evi-scaler ) ) ]
    update-maxima ]

  if day = 1 or ticks = 0
  [ if any? aeolianite_patches [ ask aeolianite_patches [ set shellfish-resources aeolianite_resources ] ]
    if any? sandy_beach_patches [ ask sandy_beach_patches [ set shellfish-resources sandy_beach_resources ] ]
    if any? boulders_patches [ ask boulders_patches [ set shellfish-resources boulders_resources ] ]
    if any? rocky_headlands_patches [ ask rocky_headlands_patches [ set shellfish-resources rocky_headlands_resources ] ]
    if any? wavecut_platforms_patches [ ask wavecut_platforms_patches [ set shellfish-resources wavecut_platforms_resources ] ] ]

  let fixer patches with [ plant-resources < 0 ]
  if any? fixer [ ask fixer [ set plant-resources 0 ] ]
  set fixer patches with [ shellfish-resources < 0 ]
  if any? fixer [ ask fixer [ set shellfish-resources 0 ] ]
end

to update-maxima
  let current-terrestrial patches with [ envirotype != "marine" ]
  let current-coastal patches with [ envirotype != "marine" and envirotype != "terrestrial" ]
  set marginal-check mean [ forage-potential ] of current-terrestrial
  set max-plantforage max [ plant-forage-potential ] of current-terrestrial
  set max-shellfishforage max [ shellfish-forage-potential ] of current-coastal
end

to update-calendar
  if month = "dec" [ ifelse day < 31 [ set day day + 1 ] [ set day 0 set month "jan" set year year + 1 set evi-counter 0 update-sealevel ] ]
  if month = "nov" [ ifelse day < 30 [ set day day + 1 ] [ set day 1 set month "dec" ] ]
  if month = "oct" [ ifelse day < 31 [ set day day + 1 ] [ set day 1 set month "nov" ] ]
  if month = "sep" [ ifelse day < 30 [ set day day + 1 ] [ set day 1 set month "oct" ] ]
  if month = "aug" [ ifelse day < 31 [ set day day + 1 ] [ set day 1 set month "sep" ] ]
  if month = "jul" [ ifelse day < 31 [ set day day + 1 ] [ set day 1 set month "aug" ] ]
  if month = "jun" [ ifelse day < 30 [ set day day + 1 ] [ set day 1 set month "jul" ] ]
  if month = "may" [ ifelse day < 31 [ set day day + 1 ] [ set day 1 set month "jun" ] ]
  if month = "apr" [ ifelse day < 30 [ set day day + 1 ] [ set day 1 set month "may" ] ]
  if month = "mar" [ ifelse day < 31 [ set day day + 1 ] [ set day 1 set month "apr" ] ]
  if month = "feb" [ ifelse day < 28 [ set day day + 1 ] [ set day 1 set month "mar" ] ]
  if month = "jan" [ ifelse day < 31 [ set day day + 1 ] [ set day 1 set month "feb" ] ]

  set evi-counter evi-counter + 1
end

;; ****************************Setup Procedures*****************************

to setup
  clear-all
  reset-ticks
  set topography gis:load-dataset "raster_topography.asc"
  set biomes gis:load-dataset "raster_biomes.asc"

  gis:set-world-envelope gis:envelope-of topography
  gis:apply-raster topography elevation
  gis:apply-raster biomes biome-code

  set evi-counter 1

  file-open "sealevel.csv"
  set sealevel_timing_list csv:from-row file-read-line
  set sealevel_rate_list csv:from-row file-read-line
  file-close

  set sealevelmod -23.84 ;; relative sea level approximately 100,000

  set sealevel_rate_counter 0
  set sealevel_timing item 1 sealevel_timing_list
  set sealevel_rate item 0 sealevel_rate_list

  set day 1
  set month "jan"
  set year 0

  file-open "resources_terrestrial.csv"
  set savanna_resources csv:from-row file-read-line
  set nama_karoo_resources csv:from-row file-read-line
  set succulent_karoo_resources csv:from-row file-read-line
  set forest_resources csv:from-row file-read-line
  set fynbos_resources csv:from-row file-read-line
  set thicket_resources csv:from-row file-read-line
  set grassland_resources csv:from-row file-read-line
  file-close

  file-open "resources_shellfish.csv"
  set aeolianite_resources 1846000
  set sandy_beach_resources 232000
  set boulders_resources 1699333
  set rocky_headlands_resources 1302000
  set wavecut_platforms_resources 1744667
  file-close

  setup-biomes

  set aeolianite_patches patches with [ envirotype = "coastal-aeolianite" ]
  set sandy_beach_patches patches with [ envirotype = "coastal-sandybeach" ]
  set boulders_patches patches with [ envirotype = "coastal-boulders" ]
  set rocky_headlands_patches patches with [ envirotype = "coastal-rockyheadlands" ]
  set wavecut_platforms_patches patches with [ envirotype = "coastal-wavecutplatforms" ]

  update-environment
  update-patch-color

  set max-plantforage max [ plant-forage-potential ] of patches
  set max-shellfishforage max [ shellfish-forage-potential ] of patches
  set successful-hunts 0

  populate-camps
  update-camp-color

  set fertility-rate 5.235
  ifelse match-birth-death
  [ set mortality-rate 5.235 ]
  [ set mortality-rate 2.65 ]

  ask patches
  [ set plant-record [ ]
    set bone-record [ ]
    set shell-record [ ]
    set lithic-record [ ]
    set oes-record [ ]
    set ochre-record [ ]
    set record [ ] ]

  set density-limit ( count patches with [ envirotype != "marine" ] ) * 0.519375
  stop-inspecting-dead-agents
end

to populate-camps
  let seed-xy min [ pycor ] of patches with [ envirotype = "terrestrial" ]
  create-camps initial-camp-count
  [ set size 4
    set color black
    set shape "person"
    set initial-population-size one-of [ 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 ]
    set population-size initial-population-size
    set energy-required ( population-size * 2400 )       ;2440.25 610.9447
    set energy-consumption-possible ( ( energy-required * 2 ) * 0.593346 )
    set proportion-of-requirement-met 0
    move-to one-of patches with [ envirotype = "terrestrial" and pycor < seed-xy + 30 ]
    set held nobody
    set target patch-here
    set starting-patch patch-here ]

  ask camps
  [ let coloroptions [ 3 4 5 6 7 8 13 14 15 16 17 18 23 24 25 26 27 28 33 34 35 36 37 38 43 44 45 46 47 48 53 54 55 56 57
      58 63 64 65 66 67 68 73 74 75 76 77 78 83 84 85 86 87 88 93 94 95 96 97 98 103 104 105 106 107 108 113 114 115 116
      117 118 123 124 125 126 127 128 133 134 135 136 137 138 ]  ;;sets a unique color for each camp at the initialization of the model
    let startcamps camps with [ color = black ]
    if any? startcamps
    [ ask startcamps
      [ set color one-of coloroptions                           ;;removes color options so each new camp will be unique
        let tmpcolor color
        set coloroptions remove color coloroptions ] ] ]
end

to setup-biomes
  ask patches with [ biome-code = 1 ] [ set biome "forest" set envirotype "terrestrial" set hunting-chance-bushbok item 4 forest_resources set hunting-chance-bushpig item 5 forest_resources set hunting-chance-duiker item 6 forest_resources set hunting-chance-grysbok item 7 forest_resources ]
  ask patches with [ biome-code = 2 ] [ set biome "fynbos" set envirotype "terrestrial" set hunting-chance-bushbok item 4 fynbos_resources set hunting-chance-bushpig item 5 fynbos_resources set hunting-chance-duiker item 6 fynbos_resources set hunting-chance-grysbok item 7 fynbos_resources ]
  ask patches with [ biome-code = 3 ] [ set biome "grassland" set envirotype "terrestrial" set hunting-chance-bushbok item 4 grassland_resources set hunting-chance-bushpig item 5 grassland_resources set hunting-chance-duiker item 6 grassland_resources set hunting-chance-grysbok item 7 grassland_resources ]
  ask patches with [ biome-code = 4 ] [ set biome "nama karoo" set envirotype "terrestrial" set hunting-chance-bushbok item 4 nama_karoo_resources set hunting-chance-bushpig item 5 nama_karoo_resources set hunting-chance-duiker item 6 nama_karoo_resources set hunting-chance-grysbok item 7 nama_karoo_resources ]
  ask patches with [ biome-code = 5 ] [ set biome "savanna" set envirotype "terrestrial" set hunting-chance-bushbok item 4 savanna_resources set hunting-chance-bushpig item 5 savanna_resources set hunting-chance-duiker item 6 savanna_resources set hunting-chance-grysbok item 7 savanna_resources ]
  ask patches with [ biome-code = 6 ] [ set biome "succulent karoo" set envirotype "terrestrial" set hunting-chance-bushbok item 4 succulent_karoo_resources set hunting-chance-bushpig item 5 succulent_karoo_resources set hunting-chance-duiker item 6 succulent_karoo_resources set hunting-chance-grysbok item 7 succulent_karoo_resources ]
  ask patches with [ biome-code = 7 ] [ set biome "thicket" set envirotype "terrestrial" set hunting-chance-bushbok item 4 thicket_resources set hunting-chance-bushpig item 5 thicket_resources set hunting-chance-duiker item 6 thicket_resources set hunting-chance-grysbok item 7 thicket_resources ]
  ask patches with [ biome-code = 9 ] [ set biome "ocean" set envirotype "marine"]
end

;; ****************************Visualization Procedures*****************************

to update-camp-color
  ifelse update_colors
  [ set colorlist [ color ] of camps
    set uniquelist colorlist
    set uniquelist remove-duplicates uniquelist ]
  [ ]
end

to update-patch-color
  if color-by = "elevation"
  [ ifelse update_colors
    [ if ticks mod 365 = 0 or ticks = 0
      [ ask patches with [ elevation >= (0 + sealevelmod) ] [ set pcolor scale-color green elevation -500 2500 ]
        ask patches with [ elevation < (0 + sealevelmod) ] [ set pcolor scale-color blue elevation -5500 2000 ] ] ]
    [ ] ]

  if color-by = "EVI"
  [ ifelse update_colors
    [ if day = 1 or ticks = 0
      [ ask patches with [ elevation >= (0 + sealevelmod) and evi-current >= 1000] [ set pcolor scale-color green evi-mean 0 10000 ]
        ask patches with [ elevation >= (0 + sealevelmod) and evi-current < 1000 ] [ set pcolor scale-color brown evi-mean -3000 2000 ]
        ask patches with [ elevation < (0 + sealevelmod) ] [ set pcolor scale-color blue elevation -5500 2000 ] ] ]
    [ ] ]

  if color-by = "biome"
  [ ifelse update_colors
    [ if ticks mod 365 = 0 or ticks = 0
      [ ask patches
        [ if biome-code = 1 [ set pcolor green ]
          if biome-code = 2 [ set pcolor green + 4 ]
          if biome-code = 3 [ set pcolor green + 2 ]
          if biome-code = 4 [ set pcolor brown + 2 ]
          if biome-code = 5 [ set pcolor green - 4 ]
          if biome-code = 6 [ set pcolor brown - 2 ]
          if biome-code = 7 [ set pcolor green + 6 ]
          if biome-code = 8 [ set pcolor brown ]
          if biome-code = 9 [ set pcolor blue ]
          if envirotype = "coastal" [ set pcolor gray ] ] ] ]
    [ ] ]

  if color-by = "resources"
  [ ask patches with [ envirotype = "terrestrial" ] [ set pcolor scale-color green plant-resources 4000000 0 ]
    ask patches with [ envirotype != "marine" and envirotype != "terrestrial" ] [ set pcolor scale-color gray shellfish-resources 7000000 0 ]
    ask patches with [ envirotype = "marine" ] [ set pcolor blue ] ]

  if color-by = "agents"
  [ ask patches
    [ if envirotype = "marine" [ set pcolor blue ]
      if envirotype = "terrestrial" [ set pcolor black ]
      if envirotype != "marine" and envirotype != "terrestrial" [ set pcolor black ] ] ]
end

to sample-record
  set campwholist [ ]
  set campstartlist [ ]
  set campendlist [ ]
  set campdistlist [ ]
  set campcolorlist [ ]
  set campmobilitylist [ ]
  set camppoplist [ ]
  let final-record n-of 100 patches with [ record-length > 0 ]
  let counter 1
  while [ any? final-record with [ site-number = 0 ] ]
  [ ask one-of final-record with [ site-number = 0 ] [ set site-number counter ]
    set counter counter + 1 ]

  if any? camps
  [ ask camps
    [ set ending-patch patch-here
      set distance-from-start distance starting-patch ] ]
  foreach sort-on [ who ] camps [ t ->
    ask t
    [ set campwholist lput who campwholist
      set campstartlist lput starting-patch campstartlist
      set campendlist lput ending-patch campendlist
      set campdistlist lput distance-from-start campdistlist
      set campcolorlist lput color campcolorlist
      set campmobilitylist lput mobility-counter campmobilitylist
      set camppoplist lput population-size camppoplist ] ]
end
@#$#@#$#@
GRAPHICS-WINDOW
219
10
953
745
-1
-1
3.612
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
200
0
200
0
0
1
ticks
30.0

BUTTON
15
10
79
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
83
10
146
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

BUTTON
150
10
213
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

CHOOSER
15
47
153
92
color-by
color-by
"elevation" "EVI" "biome" "resources" "agents"
3

MONITOR
963
12
1020
57
Year
year
17
1
11

MONITOR
1024
12
1081
57
Month
month
17
1
11

MONITOR
1085
12
1142
57
Day
day
17
1
11

MONITOR
1145
12
1212
57
EVI-count
evi-counter
17
1
11

MONITOR
963
64
1077
109
Relative Sea Level
precision sealevelmod 6
17
1
11

PLOT
963
119
1213
269
Relative Sea Level
NIL
NIL
0.0
10.0
-100.0
10.0
true
false
"" "ifelse ticks mod 365 = 0 [ ] [ stop ]"
PENS
"default" 1.0 0 -16777216 true "" "plot sealevelmod"
"pen-1" 1.0 0 -2674135 true "" "plot 0"

SWITCH
15
96
149
129
update_colors
update_colors
1
1
-1000

MONITOR
1081
64
1202
109
Sea Level Rate
precision sealevel_rate 6
17
1
11

MONITOR
963
275
1060
320
NIL
sealevel_timing
17
1
11

BUTTON
16
134
89
167
Recolor
update-patch-color
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
172
188
205
initial-camp-count
initial-camp-count
0
500
25.0
1
1
NIL
HORIZONTAL

BUTTON
92
134
163
167
Profiler
setup\nprofiler:start\nrepeat 30 [go]\nprofiler:stop\nprint profiler:report\nprofiler:reset
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1064
275
1202
320
Mean Forage Potential
round (marginal-check)
17
1
11

SLIDER
15
211
188
244
maximum-camp-movement
maximum-camp-movement
0
100
50.0
1
1
NIL
HORIZONTAL

MONITOR
963
375
1044
420
Total Camps
count camps
17
1
11

MONITOR
1048
376
1187
421
Mean Camp Population
round (mean [population-size] of camps)
17
1
11

MONITOR
963
424
1020
469
Births
sum [ birth-counter] of camps
17
1
11

MONITOR
963
325
1055
370
Average Moves
round ( (mean [ mobility-counter ] of camps) / year )
17
1
11

MONITOR
1024
424
1088
469
TFR
precision ( ( (sum [ birth-counter] of camps) / sum [ population-size ] of camps) * 100 ) 5
17
1
11

MONITOR
963
474
1020
519
Deaths
sum [ death-counter ] of camps
17
1
11

SLIDER
14
248
186
281
foraging-radius
foraging-radius
0
10
1.0
1
1
NIL
HORIZONTAL

MONITOR
964
584
1073
629
Max Aff Strength
precision (max [ affinity ] of affiliations ) 3
17
1
11

MONITOR
963
637
1052
682
Unique Colors
length uniquelist
17
1
11

MONITOR
1077
584
1181
629
Min Aff Strength
precision (min [ affinity ] of affiliations ) 3
17
1
11

MONITOR
1059
325
1165
370
Successful Hunts
successful-hunts
17
1
11

MONITOR
963
528
1063
573
Longest Record
max [ record-length ] of patches
17
1
11

SWITCH
1024
478
1180
511
match-birth-death
match-birth-death
1
1
-1000

SLIDER
15
315
187
348
run-counter
run-counter
0
100
21.0
1
1
NIL
HORIZONTAL

BUTTON
965
694
1067
727
Graphic Prep
ask patches with [ sum shell-record > 5 and sum plant-record > 5 and sum lithic-record > 1 and ( sum oes-record > 1 or sum ochre-record > 1 ) ] [ set pcolor red ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1092
424
1163
469
Population
sum [ population-size] of camps
17
1
11

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
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="paramsweep1" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world (word "results " run-counter ".csv")
set run-counter run-counter + 1</final>
    <metric>count camps</metric>
    <metric>campwholist</metric>
    <metric>campstartlist</metric>
    <metric>campendlist</metric>
    <metric>campdistlist</metric>
    <metric>campcolorlist</metric>
    <metric>campmobilitylist</metric>
    <metric>camppoplist</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 1 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 2 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 3 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 4 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 5 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 6 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 7 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 8 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 9 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 10 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 11 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 12 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 13 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 14 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 15 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 16 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 17 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 18 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 19 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 20 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 21 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 22 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 23 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 24 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 25 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 26 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 27 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 28 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 29 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 30 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 31 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 32 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 33 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 34 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 35 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 36 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 37 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 38 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 39 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 40 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 41 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 42 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 43 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 44 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 45 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 46 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 47 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 48 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 49 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 50 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 51 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 52 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 53 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 54 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 55 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 56 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 57 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 58 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 59 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 60 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 61 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 62 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 63 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 64 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 65 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 66 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 67 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 68 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 69 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 70 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 71 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 72 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 73 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 74 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 75 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 76 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 77 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 78 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 79 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 80 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 81 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 82 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 83 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 84 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 85 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 86 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 87 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 88 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 89 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 90 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 91 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 92 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 93 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 94 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 95 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 96 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 97 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 98 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 99 ]</metric>
    <metric>[ pxcor ] of one-of patches with [ site-number = 100 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 1 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 2 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 3 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 4 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 5 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 6 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 7 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 8 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 9 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 10 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 11 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 12 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 13 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 14 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 15 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 16 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 17 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 18 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 19 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 20 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 21 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 22 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 23 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 24 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 25 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 26 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 27 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 28 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 29 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 30 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 31 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 32 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 33 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 34 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 35 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 36 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 37 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 38 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 39 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 40 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 41 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 42 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 43 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 44 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 45 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 46 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 47 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 48 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 49 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 50 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 51 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 52 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 53 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 54 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 55 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 56 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 57 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 58 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 59 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 60 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 61 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 62 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 63 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 64 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 65 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 66 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 67 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 68 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 69 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 70 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 71 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 72 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 73 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 74 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 75 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 76 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 77 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 78 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 79 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 80 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 81 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 82 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 83 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 84 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 85 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 86 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 87 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 88 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 89 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 90 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 91 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 92 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 93 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 94 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 95 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 96 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 97 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 98 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 99 ]</metric>
    <metric>[ pycor ] of one-of patches with [ site-number = 100 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 1 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 2 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 3 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 4 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 5 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 6 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 7 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 8 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 9 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 10 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 11 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 12 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 13 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 14 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 15 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 16 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 17 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 18 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 19 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 20 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 21 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 22 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 23 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 24 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 25 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 26 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 27 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 28 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 29 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 30 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 31 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 32 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 33 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 34 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 35 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 36 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 37 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 38 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 39 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 40 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 41 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 42 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 43 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 44 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 45 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 46 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 47 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 48 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 49 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 50 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 51 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 52 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 53 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 54 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 55 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 56 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 57 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 58 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 59 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 60 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 61 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 62 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 63 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 64 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 65 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 66 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 67 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 68 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 69 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 70 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 71 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 72 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 73 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 74 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 75 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 76 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 77 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 78 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 79 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 80 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 81 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 82 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 83 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 84 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 85 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 86 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 87 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 88 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 89 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 90 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 91 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 92 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 93 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 94 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 95 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 96 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 97 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 98 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 99 ]</metric>
    <metric>[ plant-record ] of one-of patches with [ site-number = 100 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 1 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 2 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 3 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 4 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 5 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 6 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 7 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 8 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 9 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 10 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 11 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 12 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 13 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 14 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 15 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 16 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 17 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 18 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 19 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 20 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 21 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 22 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 23 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 24 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 25 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 26 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 27 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 28 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 29 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 30 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 31 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 32 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 33 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 34 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 35 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 36 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 37 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 38 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 39 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 40 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 41 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 42 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 43 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 44 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 45 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 46 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 47 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 48 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 49 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 50 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 51 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 52 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 53 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 54 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 55 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 56 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 57 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 58 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 59 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 60 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 61 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 62 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 63 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 64 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 65 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 66 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 67 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 68 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 69 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 70 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 71 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 72 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 73 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 74 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 75 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 76 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 77 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 78 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 79 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 80 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 81 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 82 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 83 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 84 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 85 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 86 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 87 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 88 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 89 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 90 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 91 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 92 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 93 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 94 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 95 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 96 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 97 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 98 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 99 ]</metric>
    <metric>[ bone-record ] of one-of patches with [ site-number = 100 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 1 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 2 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 3 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 4 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 5 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 6 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 7 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 8 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 9 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 10 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 11 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 12 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 13 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 14 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 15 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 16 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 17 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 18 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 19 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 20 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 21 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 22 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 23 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 24 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 25 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 26 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 27 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 28 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 29 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 30 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 31 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 32 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 33 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 34 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 35 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 36 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 37 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 38 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 39 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 40 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 41 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 42 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 43 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 44 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 45 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 46 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 47 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 48 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 49 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 50 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 51 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 52 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 53 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 54 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 55 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 56 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 57 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 58 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 59 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 60 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 61 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 62 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 63 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 64 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 65 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 66 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 67 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 68 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 69 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 70 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 71 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 72 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 73 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 74 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 75 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 76 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 77 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 78 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 79 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 80 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 81 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 82 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 83 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 84 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 85 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 86 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 87 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 88 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 89 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 90 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 91 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 92 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 93 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 94 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 95 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 96 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 97 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 98 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 99 ]</metric>
    <metric>[ shell-record ] of one-of patches with [ site-number = 100 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 1 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 2 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 3 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 4 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 5 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 6 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 7 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 8 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 9 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 10 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 11 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 12 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 13 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 14 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 15 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 16 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 17 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 18 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 19 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 20 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 21 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 22 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 23 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 24 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 25 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 26 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 27 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 28 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 29 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 30 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 31 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 32 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 33 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 34 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 35 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 36 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 37 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 38 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 39 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 40 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 41 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 42 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 43 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 44 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 45 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 46 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 47 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 48 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 49 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 50 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 51 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 52 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 53 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 54 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 55 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 56 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 57 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 58 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 59 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 60 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 61 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 62 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 63 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 64 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 65 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 66 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 67 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 68 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 69 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 70 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 71 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 72 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 73 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 74 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 75 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 76 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 77 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 78 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 79 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 80 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 81 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 82 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 83 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 84 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 85 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 86 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 87 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 88 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 89 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 90 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 91 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 92 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 93 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 94 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 95 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 96 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 97 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 98 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 99 ]</metric>
    <metric>[ ochre-record ] of one-of patches with [ site-number = 100 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 1 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 2 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 3 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 4 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 5 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 6 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 7 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 8 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 9 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 10 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 11 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 12 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 13 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 14 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 15 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 16 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 17 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 18 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 19 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 20 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 21 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 22 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 23 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 24 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 25 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 26 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 27 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 28 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 29 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 30 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 31 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 32 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 33 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 34 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 35 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 36 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 37 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 38 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 39 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 40 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 41 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 42 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 43 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 44 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 45 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 46 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 47 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 48 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 49 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 50 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 51 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 52 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 53 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 54 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 55 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 56 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 57 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 58 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 59 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 60 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 61 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 62 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 63 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 64 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 65 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 66 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 67 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 68 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 69 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 70 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 71 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 72 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 73 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 74 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 75 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 76 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 77 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 78 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 79 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 80 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 81 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 82 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 83 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 84 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 85 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 86 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 87 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 88 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 89 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 90 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 91 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 92 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 93 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 94 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 95 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 96 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 97 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 98 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 99 ]</metric>
    <metric>[ oes-record ] of one-of patches with [ site-number = 100 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 1 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 2 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 3 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 4 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 5 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 6 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 7 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 8 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 9 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 10 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 11 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 12 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 13 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 14 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 15 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 16 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 17 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 18 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 19 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 20 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 21 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 22 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 23 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 24 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 25 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 26 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 27 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 28 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 29 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 30 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 31 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 32 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 33 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 34 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 35 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 36 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 37 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 38 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 39 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 40 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 41 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 42 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 43 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 44 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 45 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 46 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 47 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 48 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 49 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 50 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 51 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 52 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 53 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 54 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 55 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 56 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 57 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 58 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 59 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 60 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 61 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 62 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 63 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 64 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 65 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 66 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 67 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 68 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 69 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 70 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 71 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 72 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 73 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 74 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 75 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 76 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 77 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 78 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 79 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 80 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 81 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 82 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 83 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 84 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 85 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 86 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 87 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 88 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 89 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 90 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 91 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 92 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 93 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 94 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 95 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 96 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 97 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 98 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 99 ]</metric>
    <metric>[ lithic-record ] of one-of patches with [ site-number = 100 ]</metric>
    <enumeratedValueSet variable="initial-camp-count">
      <value value="25"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update_colors">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foraging-radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-camp-movement">
      <value value="30"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="paramsweep2" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world (word "results " run-counter ".csv")
set run-counter run-counter + 1</final>
    <enumeratedValueSet variable="initial-camp-count">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update_colors">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foraging-radius">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-camp-movement">
      <value value="30"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="paramsweep3" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="initial-camp-count">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update_colors">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foraging-radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-camp-movement">
      <value value="50"/>
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
