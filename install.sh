patch_xml() {
  local VAR1 VAR2 NAME NAMEC VALC VAL
  NAME=$(echo "$3" | sed -r "s|^.*/.*\[@.*=\"(.*)\".*$|\1|")
  NAMEC=$(echo "$3" | sed -r "s|^.*/.*\[@(.*)=\".*\".*$|\1|")
  if [ "$(echo $4 | grep '=')" ]; then
    VALC=$(echo "$4" | sed -r "s|(.*)=.*|\1|"); VAL=$(echo "$4" | sed -r "s|.*=(.*)|\1|")
  else
    VALC="value"; VAL="$4"
  fi
  case $2 in
    *dialer_phenotype_flags*.xml)  sed -i "/#DIALERPATCHES/a\          patch_xml $1 \$MODPATH/\ '$3' \"$4\"" $INSTALLER/common/post-fs-data.sh; VAR1=boolean; VAR2=string;;
    *mixer_paths*.xml) sed -i "/#MIXERPATCHES/a\                       patch_xml $1 \$MODPATH/\$NAME '$3' \"$4\"" $INSTALLER/common/aml.sh; VAR1=ctl; VAR2=mixer;;
    *sapa_feature*.xml) sed -i "/#SAPAPATCHES/a\                        patch_xml $1 \$MODPATH/\$NAME '$3' \"$4\"" $INSTALLER/common/aml.sh; VAR1=feature; VAR2=model;;
    *mixer_gains*.xml) sed -i "/#GAINPATCHES/a\                       patch_xml $1 \$MODPATH/\$NAME '$3' \"$4\"" $INSTALLER/common/aml.sh; VAR1=ctl; VAR2=mixer;;
    *audio_device*.xml) sed -i "/#ADPATCHES/a\                        patch_xml $1 \$MODPATH/\$NAME '$3' \"$4\"" $INSTALLER/common/aml.sh; VAR1=kctl; VAR2=mixercontrol;;
    *audio_platform_info*.xml) sed -i "/#APLIPATCHES/a\                               patch_xml $1 \$MODPATH/\$NAME '$3' \"$4\"" $INSTALLER/common/aml.sh; VAR1=param; VAR2=config_params;;
  esac
  if [ "$1" == "-t" -o "$1" == "-ut" -o "$1" == "-tu" ] && [ "$VAR1" ]; then
    if [ "$(grep "<$VAR1 $NAMEC=\"$NAME\" $VALC=\".*\" />" $2)" ]; then
      sed -i "0,/<$VAR1 $NAMEC=\"$NAME\" $VALC=\".*\" \/>/ {/<$VAR1 $NAMEC=\"$NAME\" $VALC=\".*\" \/>/p; s/\(<$VAR1 $NAMEC=\"$NAME\" $VALC=\".*\" \/>\)/<!--$MODID\1$MODID-->/}" $2
      sed -i "0,/<$VAR1 $NAMEC=\"$NAME\" $VALC=\".*\" \/>/ s/\(<$VAR1 $NAMEC=\"$NAME\" $VALC=\"\).*\(\" \/>\)/\1$VAL\2<!--$MODID-->/" $2
    elif [ "$1" == "-t" ]; then
      sed -i "/<$VAR2>/ a\    <$VAR1 $NAMEC=\"$NAME\" $VALC=\"$VAL\" \/><!--$MODID-->" $2
    fi
  elif [ "$(xmlstarlet sel -t -m "$3" -c . $2)" ]; then
    [ "$(xmlstarlet sel -t -m "$3" -c . $2 | sed -r "s/.*$VALC=(\".*\").*/\1/")" == "$VAL" ] && return
    xmlstarlet ed -P -L -i "$3" -t elem -n "$MODID" $2
    sed -ri "s/(^ *)(<$MODID\/>)/\1\2\n\1/g" $2
    local LN=$(sed -n "/<$MODID\/>/=" $2)
    for i in ${LN}; do
      sed -i "$i d" $2
      case $(sed -n "$((i-1)) p" $2) in
        *">$MODID-->") sed -i -e "${i-1}s/<!--$MODID-->//" -e "${i-1}s/$/<!--$MODID-->/" $2;;
        *) sed -i "$i p" $2
           sed -ri "${i}s/(^ *)(.*)/\1<!--$MODID\2$MODID-->/" $2
           sed -i "$((i+1))s/$/<!--$MODID-->/" $2;;
      esac
    done
    case "$1" in
      "-u"|"-s") xmlstarlet ed -L -u "$3/@$VALC" -v "$VAL" $2;;
      "-d") xmlstarlet ed -L -d "$3" $2;;
    esac
  elif [ "$1" == "-s" ]; then
    local NP=$(echo "$3" | sed -r "s|(^.*)/.*$|\1|")
    local SNP=$(echo "$3" | sed -r "s|(^.*)\[.*$|\1|")
    local SN=$(echo "$3" | sed -r "s|^.*/.*/(.*)\[.*$|\1|")
    xmlstarlet ed -L -s "$NP" -t elem -n "$SN-$MODID" -i "$SNP-$MODID" -t attr -n "$NAMEC" -v "$NAME" -i "$SNP-$MODID" -t attr -n "$VALC" -v "$VAL" $2
    xmlstarlet ed -L -r "$SNP-$MODID" -v "$SN" $2
    xmlstarlet ed -L -i "$3" -t elem -n "$MODID" $2
    local LN=$(sed -n "/<$MODID\/>/=" $2)
    for i in ${LN}; do
      sed -i "$i d" $2
      sed -ri "${i}s/$/<!--$MODID-->/" $2
    done
  fi
  local LN=$(sed -n "/^ *<!--$MODID-->$/=" $2 | tac)
  for i in ${LN}; do
    sed -i "$i d" $2
    sed -ri "$((i-1))s/$/<!--$MODID-->/" $2
  done
}

# Gets stock/limit from zip name
SLIM=false; FULL=false; OVER=false BOOT=false; ACC=false
OIFS=$IFS; IFS=\|
case $(echo $(basename $ZIPFILE) | tr '[:upper:]' '[:lower:]') in
  *slim*|*Slim*|*SLIM*) SLIM=true;;
  *full*|*Full*|*FULL*) FULL=true;;
  *over*|*Over*|*OVER*) OVER=true;;
  *boot*|*Boot*|*BOOT*) BOOT=true;;
  *acc*|*Acc*|*ACC*) ACC=true;;
esac
IFS=$OIFS

## Debug Stuff
log_start
log_print "- Installing Logging Scripts/Prepping Terminal Script "
mkdir -p $UNITY$BINPATH
cp_ch -n $INSTALLER/pix3lify.sh $UNITY$BINPATH/pix3lify
log_handler "Using $BINPATH."

sed -i -e "s|<CACHELOC>|$CACHELOC|" -e "s|<BINPATH>|$BINPATH|" $UNITY$BINPATH/pix3lify
if $MAGISK; then
sed -i "s|<MODPROP>|$(echo $MOD_VER)|" $UNITY$BINPATH/pix3lify
else
  sed -i "s|<MODPROP>|$MOD_VER|" $UNITY$BINPATH/pix3lify
fi
patch_script $UNITY$BINPATH/pix3lify

if [ "$PX1" ] || [ "$PX1XL" ] || [ "$PX2" ] || [ "$PX2XL" ] || [ "$PX3" ] || [ "$PX3XL" ] || [ "$N5X" ] || [ "$N6P" ] || [ "$OOS" ]; then
  ui_print " "
  log_print "   Call Screening will enable"
  log_print "   DO YOU WANT TO ENABLE?"
  log_print "   Vol Up = Yes, Vol Down = No"
  if $VKSEL; then
    ui_print " "
    log_print "   Waiting for files..."
  else
    ui_print " "
    log_print "   Exiting from installer..."
    abort >> $INSTLOG 2>&1
  fi
fi

ui_print " "
log_print "   Removing remnants from past Screening and others installs..."
# Removes /data/resource-cache/overlays.list
OVERLAY='/data/resource-cache/overlays.list'
if [ -f "$OVERLAY" ]; then
  log_print "   Removing $OVERLAY"
  rm -f "$OVERLAY"
fi

if [ "$SLIM" == false -a "$FULL" == false -a "$OVER" == false -a "$BOOT" == false -a "$ACC" == false ]; then
    ui_print " "
    log_print " - Slim Options -"
    log_print "   Do you want to enable slim mode (heavily reduced featureset, see README)?"
    log_print "   Vol Up = Yes, Vol Down = No"
    if $VKSEL; then
      SLIM=true >> $INSTLOG 2>&1
    else
      FULL=true >> $INSTLOG 2>&1
      fi
     fi
    fi
   fi
  fi
 fi
fi

if [ $API -ge 28 ]; then
  ui_print " "
  log_print "   Enabling Google's Call Screening..."
  DPF=$(find /data/data/com.google.android.dialer*/shared_prefs/ -name "dialer_phenotype_flags.xml")
  if [ -f $DPF ]; then
    # Enabling Google's Call Screening
    patch_xml -s $DPF '/map/boolean[@name="G__speak_easy_bypass_locale_check"]' "true" >> $INSTLOG 2>&1
    patch_xml -s $DPF '/map/boolean[@name="G__speak_easy_enable_listen_in_button"]' "true" >> $INSTLOG 2>&1
    patch_xml -s $DPF '/map/boolean[@name="__data_rollout__SpeakEasy.OverrideUSLocaleCheckRollout__launched__"]' "true" >> $INSTLOG 2>&1
    patch_xml -s $DPF '/map/boolean[@name="G__enable_speakeasy_details"]' "true" >> $INSTLOG 2>&1
    patch_xml -s $DPF '/map/boolean[@name="G__speak_easy_enabled"]' "true" >> $INSTLOG 2>&1
    patch_xml -s $DPF '/map/boolean[@name="G__speakeasy_show_privacy_tour"]' "true" >> $INSTLOG 2>&1
    patch_xml -s $DPF '/map/boolean[@name="__data_rollout__SpeakEasy.SpeakEasyDetailsRollout__launched__"]' "true" >> $INSTLOG 2>&1
    patch_xml -s $DPF '/map/boolean[@name="__data_rollout__SpeakEasy.CallScreenOnPixelTwoRollout__launched__"]' "true" >> $INSTLOG 2>&1
    patch_xml -s $DPF '/map/boolean[@name="G__speakeasy_postcall_survey_enabled"]' "true" >> $INSTLOG 2>&1
  fi
fi

# Adds slim & full variables to service.sh
for i in "SLIM" "FULL"; do
  sed -i "2i $i=$(eval echo \$$i)" $INSTALLER/common/service.sh
done

cp_ch -i $INSTALLER/common/unityfiles/tools/$ARCH32/xmlstarlet $INSTALLER/system/bin/xmlstarlet

cp_ch -i $UNITY$BINPATH/pix3lify $CACHELOC/pix3lify

log_print " If you encounter any bugs or issues, please type pix3lify"
log_print " in a terminal emulator and choose yes to send logs to our server"
log_print " WE DO NOT COLLECT ANY PERSONAL INFORMATION"
