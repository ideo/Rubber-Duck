<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE eagle SYSTEM "eagle.dtd">
<eagle version="9.7.0">
<drawing>
<settings>
<setting alwaysvectorfont="no"/>
<setting verticaltext="up"/>
</settings>
<grid distance="0.1" unitdist="inch" unit="inch" style="lines" multiple="1" display="no" altdistance="0.01" altunitdist="inch" altunit="inch"/>
<layers>
<layer number="1" name="Top" color="4" fill="1" visible="no" active="no"/>
<layer number="2" name="Route2" color="16" fill="1" visible="no" active="no"/>
<layer number="3" name="Route3" color="17" fill="1" visible="no" active="no"/>
<layer number="4" name="Route4" color="18" fill="1" visible="no" active="no"/>
<layer number="5" name="Route5" color="19" fill="1" visible="no" active="no"/>
<layer number="6" name="Route6" color="25" fill="1" visible="no" active="no"/>
<layer number="7" name="Route7" color="26" fill="1" visible="no" active="no"/>
<layer number="8" name="Route8" color="27" fill="1" visible="no" active="no"/>
<layer number="9" name="Route9" color="28" fill="1" visible="no" active="no"/>
<layer number="10" name="Route10" color="29" fill="1" visible="no" active="no"/>
<layer number="11" name="Route11" color="30" fill="1" visible="no" active="no"/>
<layer number="12" name="Route12" color="20" fill="1" visible="no" active="no"/>
<layer number="13" name="Route13" color="21" fill="1" visible="no" active="no"/>
<layer number="14" name="Route14" color="22" fill="1" visible="no" active="no"/>
<layer number="15" name="Route15" color="23" fill="1" visible="no" active="no"/>
<layer number="16" name="Bottom" color="1" fill="1" visible="no" active="no"/>
<layer number="17" name="Pads" color="2" fill="1" visible="no" active="no"/>
<layer number="18" name="Vias" color="2" fill="1" visible="no" active="no"/>
<layer number="19" name="Unrouted" color="6" fill="1" visible="no" active="no"/>
<layer number="20" name="Dimension" color="24" fill="1" visible="no" active="no"/>
<layer number="21" name="tPlace" color="7" fill="1" visible="no" active="no"/>
<layer number="22" name="bPlace" color="7" fill="1" visible="no" active="no"/>
<layer number="23" name="tOrigins" color="15" fill="1" visible="no" active="no"/>
<layer number="24" name="bOrigins" color="15" fill="1" visible="no" active="no"/>
<layer number="25" name="tNames" color="7" fill="1" visible="no" active="no"/>
<layer number="26" name="bNames" color="7" fill="1" visible="no" active="no"/>
<layer number="27" name="tValues" color="7" fill="1" visible="no" active="no"/>
<layer number="28" name="bValues" color="7" fill="1" visible="no" active="no"/>
<layer number="29" name="tStop" color="7" fill="3" visible="no" active="no"/>
<layer number="30" name="bStop" color="7" fill="6" visible="no" active="no"/>
<layer number="31" name="tCream" color="7" fill="4" visible="no" active="no"/>
<layer number="32" name="bCream" color="7" fill="5" visible="no" active="no"/>
<layer number="33" name="tFinish" color="6" fill="3" visible="no" active="no"/>
<layer number="34" name="bFinish" color="6" fill="6" visible="no" active="no"/>
<layer number="35" name="tGlue" color="7" fill="4" visible="no" active="no"/>
<layer number="36" name="bGlue" color="7" fill="5" visible="no" active="no"/>
<layer number="37" name="tTest" color="7" fill="1" visible="no" active="no"/>
<layer number="38" name="bTest" color="7" fill="1" visible="no" active="no"/>
<layer number="39" name="tKeepout" color="4" fill="11" visible="no" active="no"/>
<layer number="40" name="bKeepout" color="1" fill="11" visible="no" active="no"/>
<layer number="41" name="tRestrict" color="4" fill="10" visible="no" active="no"/>
<layer number="42" name="bRestrict" color="1" fill="10" visible="no" active="no"/>
<layer number="43" name="vRestrict" color="2" fill="10" visible="no" active="no"/>
<layer number="44" name="Drills" color="7" fill="1" visible="no" active="no"/>
<layer number="45" name="Holes" color="7" fill="1" visible="no" active="no"/>
<layer number="46" name="Milling" color="3" fill="1" visible="no" active="no"/>
<layer number="47" name="Measures" color="7" fill="1" visible="no" active="no"/>
<layer number="48" name="Document" color="7" fill="1" visible="no" active="no"/>
<layer number="49" name="Reference" color="7" fill="1" visible="no" active="no"/>
<layer number="51" name="tDocu" color="7" fill="1" visible="no" active="no"/>
<layer number="52" name="bDocu" color="7" fill="1" visible="no" active="no"/>
<layer number="88" name="SimResults" color="9" fill="1" visible="yes" active="yes"/>
<layer number="89" name="SimProbes" color="9" fill="1" visible="yes" active="yes"/>
<layer number="90" name="Modules" color="5" fill="1" visible="yes" active="yes"/>
<layer number="91" name="Nets" color="2" fill="1" visible="yes" active="yes"/>
<layer number="92" name="Busses" color="1" fill="1" visible="yes" active="yes"/>
<layer number="93" name="Pins" color="2" fill="1" visible="no" active="yes"/>
<layer number="94" name="Symbols" color="4" fill="1" visible="yes" active="yes"/>
<layer number="95" name="Names" color="7" fill="1" visible="yes" active="yes"/>
<layer number="96" name="Values" color="7" fill="1" visible="yes" active="yes"/>
<layer number="97" name="Info" color="7" fill="1" visible="yes" active="yes"/>
<layer number="98" name="Guide" color="6" fill="1" visible="yes" active="yes"/>
<layer number="255" name="Undefined" color="7" fill="1" visible="yes" active="yes"/>
</layers>
<schematic xreflabel="%F%N/%S.%C%R" xrefpart="/%S.%C%R">
<libraries>
<library name="Connector" urn="urn:adsk.eagle:library:16378166">
<description>Pin Headers |Terminal blocks | D-Sub | Backplane | FFC/FPC | Socket</description>
<packages>
<package name="1X03" urn="urn:adsk.eagle:footprint:47493533/1" library_version="56">
<description>Pin Header</description>
<wire x1="-3.175" y1="1.27" x2="-1.905" y2="1.27" width="0.1524" layer="21"/>
<wire x1="-1.905" y1="1.27" x2="-1.27" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-1.27" y1="0.635" x2="-1.27" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-1.27" y1="-0.635" x2="-1.905" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-1.27" y1="0.635" x2="-0.635" y2="1.27" width="0.1524" layer="21"/>
<wire x1="-0.635" y1="1.27" x2="0.635" y2="1.27" width="0.1524" layer="21"/>
<wire x1="0.635" y1="1.27" x2="1.27" y2="0.635" width="0.1524" layer="21"/>
<wire x1="1.27" y1="0.635" x2="1.27" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="1.27" y1="-0.635" x2="0.635" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="0.635" y1="-1.27" x2="-0.635" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-0.635" y1="-1.27" x2="-1.27" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-3.81" y1="0.635" x2="-3.81" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-3.175" y1="1.27" x2="-3.81" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-3.81" y1="-0.635" x2="-3.175" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-1.905" y1="-1.27" x2="-3.175" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="1.27" y1="0.635" x2="1.905" y2="1.27" width="0.1524" layer="21"/>
<wire x1="1.905" y1="1.27" x2="3.175" y2="1.27" width="0.1524" layer="21"/>
<wire x1="3.175" y1="1.27" x2="3.81" y2="0.635" width="0.1524" layer="21"/>
<wire x1="3.81" y1="0.635" x2="3.81" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="3.81" y1="-0.635" x2="3.175" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="3.175" y1="-1.27" x2="1.905" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="1.905" y1="-1.27" x2="1.27" y2="-0.635" width="0.1524" layer="21"/>
<pad name="1" x="-2.54" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="2" x="0" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="3" x="2.54" y="0" drill="1.016" shape="long" rot="R90"/>
<rectangle x1="-0.254" y1="-0.254" x2="0.254" y2="0.254" layer="51"/>
<rectangle x1="-2.794" y1="-0.254" x2="-2.286" y2="0.254" layer="51"/>
<rectangle x1="2.286" y1="-0.254" x2="2.794" y2="0.254" layer="51"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="1X10" urn="urn:adsk.eagle:footprint:47493518/1" library_version="56">
<description>Pin Header</description>
<wire x1="7.62" y1="0.635" x2="8.255" y2="1.27" width="0.1524" layer="21"/>
<wire x1="8.255" y1="1.27" x2="9.525" y2="1.27" width="0.1524" layer="21"/>
<wire x1="9.525" y1="1.27" x2="10.16" y2="0.635" width="0.1524" layer="21"/>
<wire x1="10.16" y1="0.635" x2="10.16" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="10.16" y1="-0.635" x2="9.525" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="9.525" y1="-1.27" x2="8.255" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="8.255" y1="-1.27" x2="7.62" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="3.175" y1="1.27" x2="4.445" y2="1.27" width="0.1524" layer="21"/>
<wire x1="4.445" y1="1.27" x2="5.08" y2="0.635" width="0.1524" layer="21"/>
<wire x1="5.08" y1="0.635" x2="5.08" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="5.08" y1="-0.635" x2="4.445" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="5.08" y1="0.635" x2="5.715" y2="1.27" width="0.1524" layer="21"/>
<wire x1="5.715" y1="1.27" x2="6.985" y2="1.27" width="0.1524" layer="21"/>
<wire x1="6.985" y1="1.27" x2="7.62" y2="0.635" width="0.1524" layer="21"/>
<wire x1="7.62" y1="0.635" x2="7.62" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="7.62" y1="-0.635" x2="6.985" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="6.985" y1="-1.27" x2="5.715" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="5.715" y1="-1.27" x2="5.08" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="0" y1="0.635" x2="0.635" y2="1.27" width="0.1524" layer="21"/>
<wire x1="0.635" y1="1.27" x2="1.905" y2="1.27" width="0.1524" layer="21"/>
<wire x1="1.905" y1="1.27" x2="2.54" y2="0.635" width="0.1524" layer="21"/>
<wire x1="2.54" y1="0.635" x2="2.54" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="2.54" y1="-0.635" x2="1.905" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="1.905" y1="-1.27" x2="0.635" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="0.635" y1="-1.27" x2="0" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="3.175" y1="1.27" x2="2.54" y2="0.635" width="0.1524" layer="21"/>
<wire x1="2.54" y1="-0.635" x2="3.175" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="4.445" y1="-1.27" x2="3.175" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-4.445" y1="1.27" x2="-3.175" y2="1.27" width="0.1524" layer="21"/>
<wire x1="-3.175" y1="1.27" x2="-2.54" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-2.54" y1="0.635" x2="-2.54" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-2.54" y1="-0.635" x2="-3.175" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-2.54" y1="0.635" x2="-1.905" y2="1.27" width="0.1524" layer="21"/>
<wire x1="-1.905" y1="1.27" x2="-0.635" y2="1.27" width="0.1524" layer="21"/>
<wire x1="-0.635" y1="1.27" x2="0" y2="0.635" width="0.1524" layer="21"/>
<wire x1="0" y1="0.635" x2="0" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="0" y1="-0.635" x2="-0.635" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-0.635" y1="-1.27" x2="-1.905" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-1.905" y1="-1.27" x2="-2.54" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-7.62" y1="0.635" x2="-6.985" y2="1.27" width="0.1524" layer="21"/>
<wire x1="-6.985" y1="1.27" x2="-5.715" y2="1.27" width="0.1524" layer="21"/>
<wire x1="-5.715" y1="1.27" x2="-5.08" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-5.08" y1="0.635" x2="-5.08" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-5.08" y1="-0.635" x2="-5.715" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-5.715" y1="-1.27" x2="-6.985" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-6.985" y1="-1.27" x2="-7.62" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-4.445" y1="1.27" x2="-5.08" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-5.08" y1="-0.635" x2="-4.445" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-3.175" y1="-1.27" x2="-4.445" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-12.065" y1="1.27" x2="-10.795" y2="1.27" width="0.1524" layer="21"/>
<wire x1="-10.795" y1="1.27" x2="-10.16" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-10.16" y1="0.635" x2="-10.16" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-10.16" y1="-0.635" x2="-10.795" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-10.16" y1="0.635" x2="-9.525" y2="1.27" width="0.1524" layer="21"/>
<wire x1="-9.525" y1="1.27" x2="-8.255" y2="1.27" width="0.1524" layer="21"/>
<wire x1="-8.255" y1="1.27" x2="-7.62" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-7.62" y1="0.635" x2="-7.62" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-7.62" y1="-0.635" x2="-8.255" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-8.255" y1="-1.27" x2="-9.525" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-9.525" y1="-1.27" x2="-10.16" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-12.7" y1="0.635" x2="-12.7" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="-12.065" y1="1.27" x2="-12.7" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-12.7" y1="-0.635" x2="-12.065" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="-10.795" y1="-1.27" x2="-12.065" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="10.795" y1="1.27" x2="12.065" y2="1.27" width="0.1524" layer="21"/>
<wire x1="12.065" y1="1.27" x2="12.7" y2="0.635" width="0.1524" layer="21"/>
<wire x1="12.7" y1="0.635" x2="12.7" y2="-0.635" width="0.1524" layer="21"/>
<wire x1="12.7" y1="-0.635" x2="12.065" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="10.795" y1="1.27" x2="10.16" y2="0.635" width="0.1524" layer="21"/>
<wire x1="10.16" y1="-0.635" x2="10.795" y2="-1.27" width="0.1524" layer="21"/>
<wire x1="12.065" y1="-1.27" x2="10.795" y2="-1.27" width="0.1524" layer="21"/>
<pad name="1" x="-11.43" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="2" x="-8.89" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="3" x="-6.35" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="4" x="-3.81" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="5" x="-1.27" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="6" x="1.27" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="7" x="3.81" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="8" x="6.35" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="9" x="8.89" y="0" drill="1.016" shape="long" rot="R90"/>
<pad name="10" x="11.43" y="0" drill="1.016" shape="long" rot="R90"/>
<rectangle x1="8.636" y1="-0.254" x2="9.144" y2="0.254" layer="51"/>
<rectangle x1="6.096" y1="-0.254" x2="6.604" y2="0.254" layer="51"/>
<rectangle x1="3.556" y1="-0.254" x2="4.064" y2="0.254" layer="51"/>
<rectangle x1="1.016" y1="-0.254" x2="1.524" y2="0.254" layer="51"/>
<rectangle x1="-1.524" y1="-0.254" x2="-1.016" y2="0.254" layer="51"/>
<rectangle x1="-4.064" y1="-0.254" x2="-3.556" y2="0.254" layer="51"/>
<rectangle x1="-6.604" y1="-0.254" x2="-6.096" y2="0.254" layer="51"/>
<rectangle x1="-9.144" y1="-0.254" x2="-8.636" y2="0.254" layer="51"/>
<rectangle x1="-11.684" y1="-0.254" x2="-11.176" y2="0.254" layer="51"/>
<rectangle x1="11.176" y1="-0.254" x2="11.684" y2="0.254" layer="51"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="1X03/90" urn="urn:adsk.eagle:footprint:47493532/1" library_version="56">
<description>Pin Header</description>
<wire x1="-3.81" y1="-1.905" x2="-1.27" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="-1.27" y1="-1.905" x2="-1.27" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-1.27" y1="0.635" x2="-3.81" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-3.81" y1="0.635" x2="-3.81" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="-2.54" y1="6.985" x2="-2.54" y2="1.27" width="0.762" layer="21"/>
<wire x1="-1.27" y1="-1.905" x2="1.27" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="1.27" y1="-1.905" x2="1.27" y2="0.635" width="0.1524" layer="21"/>
<wire x1="1.27" y1="0.635" x2="-1.27" y2="0.635" width="0.1524" layer="21"/>
<wire x1="0" y1="6.985" x2="0" y2="1.27" width="0.762" layer="21"/>
<wire x1="1.27" y1="-1.905" x2="3.81" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="3.81" y1="-1.905" x2="3.81" y2="0.635" width="0.1524" layer="21"/>
<wire x1="3.81" y1="0.635" x2="1.27" y2="0.635" width="0.1524" layer="21"/>
<wire x1="2.54" y1="6.985" x2="2.54" y2="1.27" width="0.762" layer="21"/>
<pad name="1" x="-2.54" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="2" x="0" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="3" x="2.54" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<rectangle x1="-2.921" y1="0.635" x2="-2.159" y2="1.143" layer="21"/>
<rectangle x1="-0.381" y1="0.635" x2="0.381" y2="1.143" layer="21"/>
<rectangle x1="2.159" y1="0.635" x2="2.921" y2="1.143" layer="21"/>
<rectangle x1="-2.921" y1="-2.921" x2="-2.159" y2="-1.905" layer="21"/>
<rectangle x1="-0.381" y1="-2.921" x2="0.381" y2="-1.905" layer="21"/>
<rectangle x1="2.159" y1="-2.921" x2="2.921" y2="-1.905" layer="21"/>
<text x="0" y="7.62" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-6.35" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="1X10/90" urn="urn:adsk.eagle:footprint:47493519/1" library_version="56">
<description>Pin Header</description>
<wire x1="-12.7" y1="-1.905" x2="-10.16" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="-10.16" y1="-1.905" x2="-10.16" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-10.16" y1="0.635" x2="-12.7" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-12.7" y1="0.635" x2="-12.7" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="-11.43" y1="6.985" x2="-11.43" y2="1.27" width="0.762" layer="21"/>
<wire x1="-10.16" y1="-1.905" x2="-7.62" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="-7.62" y1="-1.905" x2="-7.62" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-7.62" y1="0.635" x2="-10.16" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-8.89" y1="6.985" x2="-8.89" y2="1.27" width="0.762" layer="21"/>
<wire x1="-7.62" y1="-1.905" x2="-5.08" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="-5.08" y1="-1.905" x2="-5.08" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-5.08" y1="0.635" x2="-7.62" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-6.35" y1="6.985" x2="-6.35" y2="1.27" width="0.762" layer="21"/>
<wire x1="-5.08" y1="-1.905" x2="-2.54" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="-2.54" y1="-1.905" x2="-2.54" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-2.54" y1="0.635" x2="-5.08" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-3.81" y1="6.985" x2="-3.81" y2="1.27" width="0.762" layer="21"/>
<wire x1="-2.54" y1="-1.905" x2="0" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="0" y1="-1.905" x2="0" y2="0.635" width="0.1524" layer="21"/>
<wire x1="0" y1="0.635" x2="-2.54" y2="0.635" width="0.1524" layer="21"/>
<wire x1="-1.27" y1="6.985" x2="-1.27" y2="1.27" width="0.762" layer="21"/>
<wire x1="0" y1="-1.905" x2="2.54" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="2.54" y1="-1.905" x2="2.54" y2="0.635" width="0.1524" layer="21"/>
<wire x1="2.54" y1="0.635" x2="0" y2="0.635" width="0.1524" layer="21"/>
<wire x1="1.27" y1="6.985" x2="1.27" y2="1.27" width="0.762" layer="21"/>
<wire x1="2.54" y1="-1.905" x2="5.08" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="5.08" y1="-1.905" x2="5.08" y2="0.635" width="0.1524" layer="21"/>
<wire x1="5.08" y1="0.635" x2="2.54" y2="0.635" width="0.1524" layer="21"/>
<wire x1="3.81" y1="6.985" x2="3.81" y2="1.27" width="0.762" layer="21"/>
<wire x1="5.08" y1="-1.905" x2="7.62" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="7.62" y1="-1.905" x2="7.62" y2="0.635" width="0.1524" layer="21"/>
<wire x1="7.62" y1="0.635" x2="5.08" y2="0.635" width="0.1524" layer="21"/>
<wire x1="6.35" y1="6.985" x2="6.35" y2="1.27" width="0.762" layer="21"/>
<wire x1="7.62" y1="-1.905" x2="10.16" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="10.16" y1="-1.905" x2="10.16" y2="0.635" width="0.1524" layer="21"/>
<wire x1="10.16" y1="0.635" x2="7.62" y2="0.635" width="0.1524" layer="21"/>
<wire x1="8.89" y1="6.985" x2="8.89" y2="1.27" width="0.762" layer="21"/>
<wire x1="10.16" y1="-1.905" x2="12.7" y2="-1.905" width="0.1524" layer="21"/>
<wire x1="12.7" y1="-1.905" x2="12.7" y2="0.635" width="0.1524" layer="21"/>
<wire x1="12.7" y1="0.635" x2="10.16" y2="0.635" width="0.1524" layer="21"/>
<wire x1="11.43" y1="6.985" x2="11.43" y2="1.27" width="0.762" layer="21"/>
<pad name="1" x="-11.43" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="2" x="-8.89" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="3" x="-6.35" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="4" x="-3.81" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="5" x="-1.27" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="6" x="1.27" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="7" x="3.81" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="8" x="6.35" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="9" x="8.89" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<pad name="10" x="11.43" y="-3.81" drill="1.016" shape="long" rot="R90"/>
<rectangle x1="-11.811" y1="0.635" x2="-11.049" y2="1.143" layer="21"/>
<rectangle x1="-9.271" y1="0.635" x2="-8.509" y2="1.143" layer="21"/>
<rectangle x1="-6.731" y1="0.635" x2="-5.969" y2="1.143" layer="21"/>
<rectangle x1="-4.191" y1="0.635" x2="-3.429" y2="1.143" layer="21"/>
<rectangle x1="-1.651" y1="0.635" x2="-0.889" y2="1.143" layer="21"/>
<rectangle x1="0.889" y1="0.635" x2="1.651" y2="1.143" layer="21"/>
<rectangle x1="3.429" y1="0.635" x2="4.191" y2="1.143" layer="21"/>
<rectangle x1="5.969" y1="0.635" x2="6.731" y2="1.143" layer="21"/>
<rectangle x1="8.509" y1="0.635" x2="9.271" y2="1.143" layer="21"/>
<rectangle x1="11.049" y1="0.635" x2="11.811" y2="1.143" layer="21"/>
<rectangle x1="-11.811" y1="-2.921" x2="-11.049" y2="-1.905" layer="21"/>
<rectangle x1="-9.271" y1="-2.921" x2="-8.509" y2="-1.905" layer="21"/>
<rectangle x1="-6.731" y1="-2.921" x2="-5.969" y2="-1.905" layer="21"/>
<rectangle x1="-4.191" y1="-2.921" x2="-3.429" y2="-1.905" layer="21"/>
<rectangle x1="-1.651" y1="-2.921" x2="-0.889" y2="-1.905" layer="21"/>
<rectangle x1="0.889" y1="-2.921" x2="1.651" y2="-1.905" layer="21"/>
<rectangle x1="3.429" y1="-2.921" x2="4.191" y2="-1.905" layer="21"/>
<rectangle x1="5.969" y1="-2.921" x2="6.731" y2="-1.905" layer="21"/>
<rectangle x1="8.509" y1="-2.921" x2="9.271" y2="-1.905" layer="21"/>
<rectangle x1="11.049" y1="-2.921" x2="11.811" y2="-1.905" layer="21"/>
<text x="0" y="7.62" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-6.35" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
</packages>
<packages3d>
<package3d name="1X03" urn="urn:adsk.eagle:package:47493647/1" type="model">
<description>Pin Header</description>
<packageinstances>
<packageinstance name="1X03"/>
</packageinstances>
</package3d>
<package3d name="1X10" urn="urn:adsk.eagle:package:47493623/1" type="model">
<description>Pin Header</description>
<packageinstances>
<packageinstance name="1X10"/>
</packageinstances>
</package3d>
<package3d name="1X03/90" urn="urn:adsk.eagle:package:47493650/1" type="model">
<description>Pin Header</description>
<packageinstances>
<packageinstance name="1X03/90"/>
</packageinstances>
</package3d>
<package3d name="1X10/90" urn="urn:adsk.eagle:package:47493628/1" type="model">
<description>Pin Header</description>
<packageinstances>
<packageinstance name="1X10/90"/>
</packageinstances>
</package3d>
</packages3d>
<symbols>
<symbol name="PINHD3" urn="urn:adsk.eagle:symbol:47493475/1" library_version="64">
<pin name="1" x="-5.08" y="2.54" visible="pad" length="middle" direction="pas"/>
<pin name="2" x="-5.08" y="0" visible="pad" length="middle" direction="pas"/>
<pin name="3" x="-5.08" y="-2.54" visible="pad" length="middle" direction="pas"/>
<wire x1="-1.27" y1="-5.08" x2="2.54" y2="-5.08" width="0.1524" layer="94"/>
<wire x1="2.54" y1="-5.08" x2="2.54" y2="5.08" width="0.1524" layer="94"/>
<wire x1="2.54" y1="5.08" x2="-1.27" y2="5.08" width="0.1524" layer="94"/>
<wire x1="-1.27" y1="5.08" x2="-1.27" y2="-5.08" width="0.1524" layer="94"/>
<wire x1="0" y1="2.54" x2="1.27" y2="2.54" width="0.6096" layer="94"/>
<wire x1="0" y1="0" x2="1.27" y2="0" width="0.6096" layer="94"/>
<wire x1="0" y1="-2.54" x2="1.27" y2="-2.54" width="0.6096" layer="94"/>
<text x="0" y="7.62" size="1.778" layer="95" align="top-center">&gt;NAME</text>
<text x="0" y="-7.62" size="1.778" layer="96" align="bottom-center">&gt;VALUE</text>
</symbol>
<symbol name="PINHD10" urn="urn:adsk.eagle:symbol:47493484/1" library_version="56">
<pin name="1" x="-5.08" y="10.16" visible="pad" length="middle" direction="pas"/>
<pin name="2" x="-5.08" y="7.62" visible="pad" length="middle" direction="pas"/>
<pin name="3" x="-5.08" y="5.08" visible="pad" length="middle" direction="pas"/>
<pin name="4" x="-5.08" y="2.54" visible="pad" length="middle" direction="pas"/>
<pin name="5" x="-5.08" y="0" visible="pad" length="middle" direction="pas"/>
<pin name="6" x="-5.08" y="-2.54" visible="pad" length="middle" direction="pas"/>
<pin name="7" x="-5.08" y="-5.08" visible="pad" length="middle" direction="pas"/>
<pin name="8" x="-5.08" y="-7.62" visible="pad" length="middle" direction="pas"/>
<pin name="9" x="-5.08" y="-10.16" visible="pad" length="middle" direction="pas"/>
<pin name="10" x="-5.08" y="-12.7" visible="pad" length="middle" direction="pas"/>
<wire x1="-1.27" y1="-15.24" x2="2.54" y2="-15.24" width="0.1524" layer="94"/>
<wire x1="2.54" y1="-15.24" x2="2.54" y2="12.7" width="0.1524" layer="94"/>
<wire x1="2.54" y1="12.7" x2="-1.27" y2="12.7" width="0.1524" layer="94"/>
<wire x1="-1.27" y1="12.7" x2="-1.27" y2="-15.24" width="0.1524" layer="94"/>
<wire x1="0" y1="10.16" x2="1.27" y2="10.16" width="0.6096" layer="94"/>
<wire x1="0" y1="7.62" x2="1.27" y2="7.62" width="0.6096" layer="94"/>
<wire x1="0" y1="5.08" x2="1.27" y2="5.08" width="0.6096" layer="94"/>
<wire x1="0" y1="2.54" x2="1.27" y2="2.54" width="0.6096" layer="94"/>
<wire x1="0" y1="0" x2="1.27" y2="0" width="0.6096" layer="94"/>
<wire x1="0" y1="-2.54" x2="1.27" y2="-2.54" width="0.6096" layer="94"/>
<wire x1="0" y1="-5.08" x2="1.27" y2="-5.08" width="0.6096" layer="94"/>
<wire x1="0" y1="-7.62" x2="1.27" y2="-7.62" width="0.6096" layer="94"/>
<wire x1="0" y1="-10.16" x2="1.27" y2="-10.16" width="0.6096" layer="94"/>
<wire x1="0" y1="-12.7" x2="1.27" y2="-12.7" width="0.6096" layer="94"/>
<text x="0" y="15.24" size="1.778" layer="95" align="top-center">&gt;NAME</text>
<text x="0" y="-17.78" size="1.778" layer="96" align="bottom-center">&gt;VALUE</text>
</symbol>
</symbols>
<devicesets>
<deviceset name="PINHD-1X3" urn="urn:adsk.eagle:component:16494881/8" prefix="JP" library_version="56">
<description>Pin Header</description>
<gates>
<gate name="A" symbol="PINHD3" x="0" y="0"/>
</gates>
<devices>
<device name="" package="1X03">
<connects>
<connect gate="A" pin="1" pad="1"/>
<connect gate="A" pin="2" pad="2"/>
<connect gate="A" pin="3" pad="3"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:47493647/1"/>
</package3dinstances>
<technologies>
<technology name="">
<attribute name="CATEGORY" value="Connectors" constant="no"/>
<attribute name="TYPE" value="Male Pins" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="Headers" constant="no"/>
<attribute name="DESCRIPTION" value="Header-Straight-3 Position" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="PITCH" value="0.100&quot; (2.54mm)" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Through Hole" constant="no"/>
</technology>
</technologies>
</device>
<device name="/90" package="1X03/90">
<connects>
<connect gate="A" pin="1" pad="1"/>
<connect gate="A" pin="2" pad="2"/>
<connect gate="A" pin="3" pad="3"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:47493650/1"/>
</package3dinstances>
<technologies>
<technology name="">
<attribute name="CATEGORY" value="Connectors" constant="no"/>
<attribute name="TYPE" value="Male Pins" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="Headers" constant="no"/>
<attribute name="DESCRIPTION" value="Header-Right Angle-3 Position" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="PITCH" value="0.100&quot; (2.54mm)" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Through Hole" constant="no"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="PINHD-1X10" urn="urn:adsk.eagle:component:16494880/8" prefix="JP" library_version="56">
<description>Pin Header</description>
<gates>
<gate name="A" symbol="PINHD10" x="0" y="0"/>
</gates>
<devices>
<device name="" package="1X10">
<connects>
<connect gate="A" pin="1" pad="1"/>
<connect gate="A" pin="10" pad="10"/>
<connect gate="A" pin="2" pad="2"/>
<connect gate="A" pin="3" pad="3"/>
<connect gate="A" pin="4" pad="4"/>
<connect gate="A" pin="5" pad="5"/>
<connect gate="A" pin="6" pad="6"/>
<connect gate="A" pin="7" pad="7"/>
<connect gate="A" pin="8" pad="8"/>
<connect gate="A" pin="9" pad="9"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:47493623/1"/>
</package3dinstances>
<technologies>
<technology name="">
<attribute name="CATEGORY" value="Connectors" constant="no"/>
<attribute name="TYPE" value="Male Pins" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="Headers" constant="no"/>
<attribute name="DESCRIPTION" value="Header-Straight-10 Position " constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="PITCH" value="0.100&quot; (2.54mm)" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Through Hole" constant="no"/>
</technology>
</technologies>
</device>
<device name="/90" package="1X10/90">
<connects>
<connect gate="A" pin="1" pad="1"/>
<connect gate="A" pin="10" pad="10"/>
<connect gate="A" pin="2" pad="2"/>
<connect gate="A" pin="3" pad="3"/>
<connect gate="A" pin="4" pad="4"/>
<connect gate="A" pin="5" pad="5"/>
<connect gate="A" pin="6" pad="6"/>
<connect gate="A" pin="7" pad="7"/>
<connect gate="A" pin="8" pad="8"/>
<connect gate="A" pin="9" pad="9"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:47493628/1"/>
</package3dinstances>
<technologies>
<technology name="">
<attribute name="CATEGORY" value="Connectors" constant="no"/>
<attribute name="TYPE" value="Male Pins" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="Headers" constant="no"/>
<attribute name="DESCRIPTION" value="Header-Right  Angle-10 Position " constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="PITCH" value="0.100&quot; (2.54mm)" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Through Hole" constant="no"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
</devicesets>
</library>
<library name="Power_Symbols" urn="urn:adsk.eagle:library:16502351">
<description>&lt;B&gt;Supply &amp; Ground symbols</description>
<packages>
</packages>
<symbols>
<symbol name="GND" urn="urn:adsk.eagle:symbol:16502380/3" library_version="25">
<description>Ground (GND) Arrow</description>
<wire x1="-1.27" y1="0" x2="1.27" y2="0" width="0.1524" layer="94"/>
<wire x1="1.27" y1="0" x2="0" y2="-1.27" width="0.1524" layer="94"/>
<wire x1="0" y1="-1.27" x2="-1.27" y2="0" width="0.1524" layer="94"/>
<pin name="GND" x="0" y="2.54" visible="off" length="short" direction="sup" rot="R270"/>
<text x="0" y="-2.54" size="1.778" layer="96" align="top-center">&gt;VALUE</text>
</symbol>
<symbol name="VDD" urn="urn:adsk.eagle:symbol:35782169/2" library_version="25">
<pin name="VDD" x="0" y="0" visible="off" length="short" direction="sup" rot="R90"/>
<wire x1="-1.905" y1="2.54" x2="1.905" y2="2.54" width="0.1524" layer="94"/>
<text x="0" y="5.08" size="1.778" layer="96" align="top-center">&gt;VALUE</text>
</symbol>
</symbols>
<devicesets>
<deviceset name="GND" urn="urn:adsk.eagle:component:16502425/6" prefix="SUPPLY" uservalue="yes" library_version="23">
<description>&lt;b&gt;SUPPLY SYMBOL&lt;/b&gt; - Ground (GND) Arrow</description>
<gates>
<gate name="G$1" symbol="GND" x="0" y="0"/>
</gates>
<devices>
<device name="">
<technologies>
<technology name="">
<attribute name="CATEGORY" value="Supply" constant="no"/>
<attribute name="VALUE" value="GND" constant="no"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="VDD" urn="urn:adsk.eagle:component:18498258/7" prefix="SUPPLY" uservalue="yes" library_version="23">
<description>&lt;b&gt;SUPPLY SYMBOL&lt;/b&gt;  VDD Bar</description>
<gates>
<gate name="G$1" symbol="VDD" x="0" y="0"/>
</gates>
<devices>
<device name="">
<technologies>
<technology name="">
<attribute name="CATEGORY" value="Supply" constant="no"/>
<attribute name="VALUE" value="VDD" constant="no"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
</devicesets>
</library>
<library name="Capacitor" urn="urn:adsk.eagle:library:16290819">
<description>&lt;B&gt;Capacitors - Fixed, Variable, Trimmers</description>
<packages>
<package name="CAPC1005X60" urn="urn:adsk.eagle:footprint:16290849/6" library_version="24">
<description>Chip, 1.00 X 0.50 X 0.60 mm body
&lt;p&gt;Chip package with body size 1.00 X 0.50 X 0.60 mm&lt;/p&gt;</description>
<wire x1="0.55" y1="0.6286" x2="-0.55" y2="0.6286" width="0.127" layer="21"/>
<wire x1="0.55" y1="-0.6286" x2="-0.55" y2="-0.6286" width="0.127" layer="21"/>
<wire x1="0.55" y1="-0.3" x2="-0.55" y2="-0.3" width="0.12" layer="51"/>
<wire x1="-0.55" y1="-0.3" x2="-0.55" y2="0.3" width="0.12" layer="51"/>
<wire x1="-0.55" y1="0.3" x2="0.55" y2="0.3" width="0.12" layer="51"/>
<wire x1="0.55" y1="0.3" x2="0.55" y2="-0.3" width="0.12" layer="51"/>
<smd name="1" x="-0.4846" y="0" dx="0.56" dy="0.6291" layer="1"/>
<smd name="2" x="0.4846" y="0" dx="0.56" dy="0.6291" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="CAPC1110X102" urn="urn:adsk.eagle:footprint:16290845/6" library_version="24">
<description>Chip, 1.17 X 1.02 X 1.02 mm body
&lt;p&gt;Chip package with body size 1.17 X 1.02 X 1.02 mm&lt;/p&gt;</description>
<wire x1="0.66" y1="0.9552" x2="-0.66" y2="0.9552" width="0.127" layer="21"/>
<wire x1="0.66" y1="-0.9552" x2="-0.66" y2="-0.9552" width="0.127" layer="21"/>
<wire x1="0.66" y1="-0.635" x2="-0.66" y2="-0.635" width="0.12" layer="51"/>
<wire x1="-0.66" y1="-0.635" x2="-0.66" y2="0.635" width="0.12" layer="51"/>
<wire x1="-0.66" y1="0.635" x2="0.66" y2="0.635" width="0.12" layer="51"/>
<wire x1="0.66" y1="0.635" x2="0.66" y2="-0.635" width="0.12" layer="51"/>
<smd name="1" x="-0.5388" y="0" dx="0.6626" dy="1.2823" layer="1"/>
<smd name="2" x="0.5388" y="0" dx="0.6626" dy="1.2823" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="CAPC1608X85" urn="urn:adsk.eagle:footprint:16290847/6" library_version="24">
<description>Chip, 1.60 X 0.80 X 0.85 mm body
&lt;p&gt;Chip package with body size 1.60 X 0.80 X 0.85 mm&lt;/p&gt;</description>
<wire x1="0.875" y1="0.7991" x2="-0.875" y2="0.7991" width="0.127" layer="21"/>
<wire x1="0.875" y1="-0.7991" x2="-0.875" y2="-0.7991" width="0.127" layer="21"/>
<wire x1="0.875" y1="-0.475" x2="-0.875" y2="-0.475" width="0.12" layer="51"/>
<wire x1="-0.875" y1="-0.475" x2="-0.875" y2="0.475" width="0.12" layer="51"/>
<wire x1="-0.875" y1="0.475" x2="0.875" y2="0.475" width="0.12" layer="51"/>
<wire x1="0.875" y1="0.475" x2="0.875" y2="-0.475" width="0.12" layer="51"/>
<smd name="1" x="-0.7746" y="0" dx="0.9209" dy="0.9702" layer="1"/>
<smd name="2" x="0.7746" y="0" dx="0.9209" dy="0.9702" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="CAPC2012X110" urn="urn:adsk.eagle:footprint:16290848/6" library_version="24">
<description>Chip, 2.00 X 1.25 X 1.10 mm body
&lt;p&gt;Chip package with body size 2.00 X 1.25 X 1.10 mm&lt;/p&gt;</description>
<wire x1="1.1" y1="1.0467" x2="-1.1" y2="1.0467" width="0.127" layer="21"/>
<wire x1="1.1" y1="-1.0467" x2="-1.1" y2="-1.0467" width="0.127" layer="21"/>
<wire x1="1.1" y1="-0.725" x2="-1.1" y2="-0.725" width="0.12" layer="51"/>
<wire x1="-1.1" y1="-0.725" x2="-1.1" y2="0.725" width="0.12" layer="51"/>
<wire x1="-1.1" y1="0.725" x2="1.1" y2="0.725" width="0.12" layer="51"/>
<wire x1="1.1" y1="0.725" x2="1.1" y2="-0.725" width="0.12" layer="51"/>
<smd name="1" x="-0.8754" y="0" dx="1.1646" dy="1.4653" layer="1"/>
<smd name="2" x="0.8754" y="0" dx="1.1646" dy="1.4653" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="CAPC3216X135" urn="urn:adsk.eagle:footprint:16290836/6" library_version="24">
<description>Chip, 3.20 X 1.60 X 1.35 mm body
&lt;p&gt;Chip package with body size 3.20 X 1.60 X 1.35 mm&lt;/p&gt;</description>
<wire x1="1.7" y1="1.2217" x2="-1.7" y2="1.2217" width="0.127" layer="21"/>
<wire x1="1.7" y1="-1.2217" x2="-1.7" y2="-1.2217" width="0.127" layer="21"/>
<wire x1="1.7" y1="-0.9" x2="-1.7" y2="-0.9" width="0.12" layer="51"/>
<wire x1="-1.7" y1="-0.9" x2="-1.7" y2="0.9" width="0.12" layer="51"/>
<wire x1="-1.7" y1="0.9" x2="1.7" y2="0.9" width="0.12" layer="51"/>
<wire x1="1.7" y1="0.9" x2="1.7" y2="-0.9" width="0.12" layer="51"/>
<smd name="1" x="-1.4754" y="0" dx="1.1646" dy="1.8153" layer="1"/>
<smd name="2" x="1.4754" y="0" dx="1.1646" dy="1.8153" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="CAPC3225X135" urn="urn:adsk.eagle:footprint:16290843/6" library_version="24">
<description>Chip, 3.20 X 2.50 X 1.35 mm body
&lt;p&gt;Chip package with body size 3.20 X 2.50 X 1.35 mm&lt;/p&gt;</description>
<wire x1="1.7" y1="1.6717" x2="-1.7" y2="1.6717" width="0.127" layer="21"/>
<wire x1="1.7" y1="-1.6717" x2="-1.7" y2="-1.6717" width="0.12" layer="21"/>
<wire x1="1.7" y1="-1.35" x2="-1.7" y2="-1.35" width="0.12" layer="51"/>
<wire x1="-1.7" y1="-1.35" x2="-1.7" y2="1.35" width="0.12" layer="51"/>
<wire x1="-1.7" y1="1.35" x2="1.7" y2="1.35" width="0.12" layer="51"/>
<wire x1="1.7" y1="1.35" x2="1.7" y2="-1.35" width="0.12" layer="51"/>
<smd name="1" x="-1.4754" y="0" dx="1.1646" dy="2.7153" layer="1"/>
<smd name="2" x="1.4754" y="0" dx="1.1646" dy="2.7153" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="CAPC4532X135" urn="urn:adsk.eagle:footprint:16290841/6" library_version="24">
<description>Chip, 4.50 X 3.20 X 1.35 mm body
&lt;p&gt;Chip package with body size 4.50 X 3.20 X 1.35 mm&lt;/p&gt;</description>
<wire x1="2.4" y1="2.0217" x2="-2.4" y2="2.0217" width="0.127" layer="21"/>
<wire x1="2.4" y1="-2.0217" x2="-2.4" y2="-2.0217" width="0.127" layer="21"/>
<wire x1="2.4" y1="-1.7" x2="-2.4" y2="-1.7" width="0.12" layer="51"/>
<wire x1="-2.4" y1="-1.7" x2="-2.4" y2="1.7" width="0.12" layer="51"/>
<wire x1="-2.4" y1="1.7" x2="2.4" y2="1.7" width="0.12" layer="51"/>
<wire x1="2.4" y1="1.7" x2="2.4" y2="-1.7" width="0.12" layer="51"/>
<smd name="1" x="-2.0565" y="0" dx="1.3973" dy="3.4153" layer="1"/>
<smd name="2" x="2.0565" y="0" dx="1.3973" dy="3.4153" layer="1"/>
<text x="0" y="3.81" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-3.81" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="CAPM3216X180" urn="urn:adsk.eagle:footprint:16290835/6" library_version="24">
<description>Molded Body, 3.20 X 1.60 X 1.80 mm body
&lt;p&gt;Molded Body package with body size 3.20 X 1.60 X 1.80 mm&lt;/p&gt;</description>
<wire x1="-1.7" y1="0.9084" x2="1.7" y2="0.9084" width="0.127" layer="21"/>
<wire x1="-1.7" y1="-0.9084" x2="1.7" y2="-0.9084" width="0.127" layer="21"/>
<wire x1="1.7" y1="-0.9" x2="-1.7" y2="-0.9" width="0.12" layer="51"/>
<wire x1="-1.7" y1="-0.9" x2="-1.7" y2="0.9" width="0.12" layer="51"/>
<wire x1="-1.7" y1="0.9" x2="1.7" y2="0.9" width="0.12" layer="51"/>
<wire x1="1.7" y1="0.9" x2="1.7" y2="-0.9" width="0.12" layer="51"/>
<smd name="1" x="-1.3099" y="0" dx="1.7955" dy="1.1887" layer="1"/>
<smd name="2" x="1.3099" y="0" dx="1.7955" dy="1.1887" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="CAPM3528X210" urn="urn:adsk.eagle:footprint:16290844/6" library_version="24">
<description>Molded Body, 3.50 X 2.80 X 2.10 mm body
&lt;p&gt;Molded Body package with body size 3.50 X 2.80 X 2.10 mm&lt;/p&gt;</description>
<wire x1="-1.85" y1="1.5" x2="1.85" y2="1.5" width="0.127" layer="21"/>
<wire x1="-1.85" y1="-1.5" x2="1.85" y2="-1.5" width="0.127" layer="21"/>
<wire x1="1.85" y1="-1.5" x2="-1.85" y2="-1.5" width="0.12" layer="51"/>
<wire x1="-1.85" y1="-1.5" x2="-1.85" y2="1.5" width="0.12" layer="51"/>
<wire x1="-1.85" y1="1.5" x2="1.85" y2="1.5" width="0.12" layer="51"/>
<wire x1="1.85" y1="1.5" x2="1.85" y2="-1.5" width="0.12" layer="51"/>
<smd name="1" x="-1.4599" y="0" dx="1.7955" dy="2.2036" layer="1"/>
<smd name="2" x="1.4599" y="0" dx="1.7955" dy="2.2036" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="CAPM6032X280" urn="urn:adsk.eagle:footprint:16290839/6" library_version="24">
<description>Molded Body, 6.00 X 3.20 X 2.80 mm body
&lt;p&gt;Molded Body package with body size 6.00 X 3.20 X 2.80 mm&lt;/p&gt;</description>
<wire x1="-3.15" y1="1.75" x2="3.15" y2="1.75" width="0.127" layer="21"/>
<wire x1="-3.15" y1="-1.75" x2="3.15" y2="-1.75" width="0.127" layer="21"/>
<wire x1="3.15" y1="-1.75" x2="-3.15" y2="-1.75" width="0.12" layer="51"/>
<wire x1="-3.15" y1="-1.75" x2="-3.15" y2="1.75" width="0.12" layer="51"/>
<wire x1="-3.15" y1="1.75" x2="3.15" y2="1.75" width="0.12" layer="51"/>
<wire x1="3.15" y1="1.75" x2="3.15" y2="-1.75" width="0.12" layer="51"/>
<smd name="1" x="-2.4712" y="0" dx="2.368" dy="2.2036" layer="1"/>
<smd name="2" x="2.4712" y="0" dx="2.368" dy="2.2036" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="CAPM7343X310" urn="urn:adsk.eagle:footprint:16290840/6" library_version="24">
<description>Molded Body, 7.30 X 4.30 X 3.10 mm body
&lt;p&gt;Molded Body package with body size 7.30 X 4.30 X 3.10 mm&lt;/p&gt;</description>
<wire x1="-3.8" y1="2.3" x2="3.8" y2="2.3" width="0.127" layer="21"/>
<wire x1="-3.8" y1="-2.3" x2="3.8" y2="-2.3" width="0.127" layer="21"/>
<wire x1="3.8" y1="-2.3" x2="-3.8" y2="-2.3" width="0.12" layer="51"/>
<wire x1="-3.8" y1="-2.3" x2="-3.8" y2="2.3" width="0.12" layer="51"/>
<wire x1="-3.8" y1="2.3" x2="3.8" y2="2.3" width="0.12" layer="51"/>
<wire x1="3.8" y1="2.3" x2="3.8" y2="-2.3" width="0.12" layer="51"/>
<smd name="1" x="-3.1212" y="0" dx="2.368" dy="2.4036" layer="1"/>
<smd name="2" x="3.1212" y="0" dx="2.368" dy="2.4036" layer="1"/>
<text x="0" y="3.81" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-3.81" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="CAPC4564X110" urn="urn:adsk.eagle:footprint:16290837/6" library_version="24">
<description>Chip, 4.50 X 6.40 X 1.10 mm body
&lt;p&gt;Chip package with body size 4.50 X 6.40 X 1.10 mm&lt;/p&gt;</description>
<wire x1="2.4" y1="3.7179" x2="-2.4" y2="3.7179" width="0.127" layer="21"/>
<wire x1="2.4" y1="-3.7179" x2="-2.4" y2="-3.7179" width="0.127" layer="21"/>
<wire x1="2.4" y1="-3.4" x2="-2.4" y2="-3.4" width="0.12" layer="51"/>
<wire x1="-2.4" y1="-3.4" x2="-2.4" y2="3.4" width="0.12" layer="51"/>
<wire x1="-2.4" y1="3.4" x2="2.4" y2="3.4" width="0.12" layer="51"/>
<wire x1="2.4" y1="3.4" x2="2.4" y2="-3.4" width="0.12" layer="51"/>
<smd name="1" x="-2.0565" y="0" dx="1.3973" dy="6.8078" layer="1"/>
<smd name="2" x="2.0565" y="0" dx="1.3973" dy="6.8078" layer="1"/>
<text x="0" y="5.08" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-5.08" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="CAPRD550W60D1025H1250B" urn="urn:adsk.eagle:footprint:16290829/6" library_version="24">
<description>Radial Non-Polarized Capacitor, 5.50 mm pitch, 10.25 mm body diameter, 12.50 mm body height
&lt;p&gt;Radial Non-Polarized Capacitor package with 5.50 mm pitch (lead spacing), 0.60 mm lead diameter, 10.25 mm body diameter and 12.50 mm body height&lt;/p&gt;</description>
<circle x="0" y="0" radius="5.25" width="0.127" layer="21"/>
<circle x="0" y="0" radius="5.25" width="0.12" layer="51"/>
<pad name="1" x="-2.75" y="0" drill="0.8" diameter="1.4"/>
<pad name="2" x="2.75" y="0" drill="0.8" diameter="1.4"/>
<text x="0" y="6.35" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-6.35" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="CAPRD2261W240D5080H5555B" urn="urn:adsk.eagle:footprint:16290850/6" library_version="24">
<description>Radial Non-Polarized Capacitor, 22.61 mm pitch, 50.80 mm body diameter, 55.55 mm body height
&lt;p&gt;Radial Non-Polarized Capacitor package with 22.61 mm pitch (lead spacing), 2.40 mm lead diameter, 50.80 mm body diameter and 55.55 mm body height&lt;/p&gt;</description>
<circle x="0" y="0" radius="25.79" width="0.127" layer="21"/>
<circle x="0" y="0" radius="25.79" width="0.12" layer="51"/>
<pad name="1" x="-11.305" y="0" drill="2.6" diameter="3.9"/>
<pad name="2" x="11.305" y="0" drill="2.6" diameter="3.9"/>
<text x="0" y="26.67" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-26.67" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
</packages>
<packages3d>
<package3d name="CAPC1005X60" urn="urn:adsk.eagle:package:16290895/6" type="model">
<description>Chip, 1.00 X 0.50 X 0.60 mm body
&lt;p&gt;Chip package with body size 1.00 X 0.50 X 0.60 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC1005X60"/>
</packageinstances>
</package3d>
<package3d name="CAPC1110X102" urn="urn:adsk.eagle:package:16290904/6" type="model">
<description>Chip, 1.17 X 1.02 X 1.02 mm body
&lt;p&gt;Chip package with body size 1.17 X 1.02 X 1.02 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC1110X102"/>
</packageinstances>
</package3d>
<package3d name="CAPC1608X85" urn="urn:adsk.eagle:package:16290898/6" type="model">
<description>Chip, 1.60 X 0.80 X 0.85 mm body
&lt;p&gt;Chip package with body size 1.60 X 0.80 X 0.85 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC1608X85"/>
</packageinstances>
</package3d>
<package3d name="CAPC2012X110" urn="urn:adsk.eagle:package:16290897/6" type="model">
<description>Chip, 2.00 X 1.25 X 1.10 mm body
&lt;p&gt;Chip package with body size 2.00 X 1.25 X 1.10 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC2012X110"/>
</packageinstances>
</package3d>
<package3d name="CAPC3216X135" urn="urn:adsk.eagle:package:16290893/6" type="model">
<description>Chip, 3.20 X 1.60 X 1.35 mm body
&lt;p&gt;Chip package with body size 3.20 X 1.60 X 1.35 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC3216X135"/>
</packageinstances>
</package3d>
<package3d name="CAPC3225X135" urn="urn:adsk.eagle:package:16290903/6" type="model">
<description>Chip, 3.20 X 2.50 X 1.35 mm body
&lt;p&gt;Chip package with body size 3.20 X 2.50 X 1.35 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC3225X135"/>
</packageinstances>
</package3d>
<package3d name="CAPC4532X135" urn="urn:adsk.eagle:package:16290900/6" type="model">
<description>Chip, 4.50 X 3.20 X 1.35 mm body
&lt;p&gt;Chip package with body size 4.50 X 3.20 X 1.35 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC4532X135"/>
</packageinstances>
</package3d>
<package3d name="CAPM3216X180" urn="urn:adsk.eagle:package:16290894/6" type="model">
<description>Molded Body, 3.20 X 1.60 X 1.80 mm body
&lt;p&gt;Molded Body package with body size 3.20 X 1.60 X 1.80 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPM3216X180"/>
</packageinstances>
</package3d>
<package3d name="CAPM3528X210" urn="urn:adsk.eagle:package:16290902/6" type="model">
<description>Molded Body, 3.50 X 2.80 X 2.10 mm body
&lt;p&gt;Molded Body package with body size 3.50 X 2.80 X 2.10 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPM3528X210"/>
</packageinstances>
</package3d>
<package3d name="CAPM6032X280" urn="urn:adsk.eagle:package:16290896/6" type="model">
<description>Molded Body, 6.00 X 3.20 X 2.80 mm body
&lt;p&gt;Molded Body package with body size 6.00 X 3.20 X 2.80 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPM6032X280"/>
</packageinstances>
</package3d>
<package3d name="CAPM7343X310" urn="urn:adsk.eagle:package:16290891/6" type="model">
<description>Molded Body, 7.30 X 4.30 X 3.10 mm body
&lt;p&gt;Molded Body package with body size 7.30 X 4.30 X 3.10 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPM7343X310"/>
</packageinstances>
</package3d>
<package3d name="CAPC4564X110L" urn="urn:adsk.eagle:package:16290887/7" type="model">
<description>Chip, 4.50 X 6.40 X 1.10 mm body
&lt;p&gt;Chip package with body size 4.50 X 6.40 X 1.10 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC4564X110"/>
</packageinstances>
</package3d>
<package3d name="CAPRD550W60D1025H1250B" urn="urn:adsk.eagle:package:16290858/6" type="model">
<description>Radial Non-Polarized Capacitor, 5.50 mm pitch, 10.25 mm body diameter, 12.50 mm body height
&lt;p&gt;Radial Non-Polarized Capacitor package with 5.50 mm pitch (lead spacing), 0.60 mm lead diameter, 10.25 mm body diameter and 12.50 mm body height&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPRD550W60D1025H1250B"/>
</packageinstances>
</package3d>
<package3d name="CAPRD2261W240D5080H5555B" urn="urn:adsk.eagle:package:16290864/6" type="model">
<description>Radial Non-Polarized Capacitor, 22.61 mm pitch, 50.80 mm body diameter, 55.55 mm body height
&lt;p&gt;Radial Non-Polarized Capacitor package with 22.61 mm pitch (lead spacing), 2.40 mm lead diameter, 50.80 mm body diameter and 55.55 mm body height&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPRD2261W240D5080H5555B"/>
</packageinstances>
</package3d>
</packages3d>
<symbols>
<symbol name="C" urn="urn:adsk.eagle:symbol:16290820/3" library_version="24">
<description>General capacitor (IEC‑style)</description>
<wire x1="-2.54" y1="0" x2="-0.254" y2="0" width="0.1524" layer="94"/>
<wire x1="2.54" y1="0" x2="0.254" y2="0" width="0.1524" layer="94"/>
<wire x1="-0.254" y1="2.032" x2="-0.254" y2="0" width="0.1524" layer="94"/>
<wire x1="-0.254" y1="0" x2="-0.254" y2="-2.032" width="0.1524" layer="94"/>
<wire x1="0.254" y1="2.032" x2="0.254" y2="0" width="0.1524" layer="94"/>
<wire x1="0.254" y1="0" x2="0.254" y2="-2.032" width="0.1524" layer="94"/>
<pin name="1" x="-2.54" y="0" visible="off" length="point" direction="pas" swaplevel="1"/>
<pin name="2" x="2.54" y="0" visible="off" length="point" direction="pas" swaplevel="1" rot="R180"/>
<text x="0" y="2.54" size="1.778" layer="95" align="bottom-center">&gt;NAME</text>
<text x="0" y="-5.08" size="1.778" layer="97" align="top-center">&gt;SPICEMODEL</text>
<text x="0" y="-2.54" size="1.778" layer="96" align="top-center">&gt;VALUE</text>
<text x="0" y="-7.62" size="1.778" layer="97" align="top-center">&gt;SPICEEXTRA</text>
</symbol>
</symbols>
<devicesets>
<deviceset name="C" urn="urn:adsk.eagle:component:16290909/12" prefix="C" uservalue="yes" library_version="24">
<description>Capacitor - Generic</description>
<gates>
<gate name="G$1" symbol="C" x="0" y="0"/>
</gates>
<devices>
<device name="CHIP-0402(1005-METRIC)" package="CAPC1005X60">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290895/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0402" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Ceramic Capacitors" constant="no"/>
<attribute name="TYPE" value="MLCC" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-0504(1310-METRIC)" package="CAPC1110X102">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290904/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0504" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Ceramic Capacitors" constant="no"/>
<attribute name="TYPE" value="MLCC" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-0603(1608-METRIC)" package="CAPC1608X85">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290898/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0603" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Ceramic Capacitors" constant="no"/>
<attribute name="TYPE" value="MLCC" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-0805(2012-METRIC)" package="CAPC2012X110">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290897/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0805" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Ceramic Capacitors" constant="no"/>
<attribute name="TYPE" value="MLCC" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1206(3216-METRIC)" package="CAPC3216X135">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290893/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1206" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Ceramic Capacitors" constant="no"/>
<attribute name="TYPE" value="MLCC" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1210(3225-METRIC)" package="CAPC3225X135">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290903/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1210" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Ceramic Capacitors" constant="no"/>
<attribute name="TYPE" value="MLCC" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1812(4532-METRIC)" package="CAPC4532X135">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290900/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1812" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Ceramic Capacitors" constant="no"/>
<attribute name="TYPE" value="MLCC" constant="no"/>
</technology>
</technologies>
</device>
<device name="TANTALUM-1206(3216-METRIC)" package="CAPM3216X180">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290894/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1206" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Tantalum Capacitors" constant="no"/>
<attribute name="TYPE" value="Polymer Capacitors" constant="no"/>
</technology>
</technologies>
</device>
<device name="TANTALUM-1411(3528-METRIC)" package="CAPM3528X210">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290902/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1411" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Tantalum Capacitors" constant="no"/>
<attribute name="TYPE" value="Polymer Capacitors" constant="no"/>
</technology>
</technologies>
</device>
<device name="TANTALUM-2412(6032-METRIC)" package="CAPM6032X280">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290896/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="2412" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Tantalum Capacitors" constant="no"/>
<attribute name="TYPE" value="Polymer Capacitors" constant="no"/>
</technology>
</technologies>
</device>
<device name="TANTALUM-2917(7343-METRIC)" package="CAPM7343X310">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290891/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="2917" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Tantalum Capacitors" constant="no"/>
<attribute name="TYPE" value="Polymer Capacitors" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1825(4564-METRIC)" package="CAPC4564X110">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290887/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1825" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
<attribute name="SUBCATEGORY" value="Ceramic Capacitors" constant="no"/>
<attribute name="TYPE" value="MLCC" constant="no"/>
</technology>
</technologies>
</device>
<device name="RADIAL-12.5MM-DIA" package="CAPRD550W60D1025H1250B">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290858/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="12.5MM-DIA" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Through Hole" constant="no"/>
<attribute name="SUBCATEGORY" value="Aluminum Non-Polar Capacitors" constant="no"/>
<attribute name="TYPE" value="Radial Can" constant="no"/>
</technology>
</technologies>
</device>
<device name="RADIAL-55.5MM-DIA" package="CAPRD2261W240D5080H5555B">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290864/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="55.5MM-DIA" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Through Hole" constant="no"/>
<attribute name="SUBCATEGORY" value="Aluminum Non-Polar Capacitors" constant="no"/>
<attribute name="TYPE" value="Radian Can" constant="no"/>
</technology>
</technologies>
</device>
</devices>
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
</deviceset>
</devicesets>
</library>
<library name="Tutorial - Fusion 360" urn="urn:adsk.eagle:library:16997205">
<description>Library of several components used in the Getting Started With Fusion Electronics tutorial.</description>
<packages>
<package name="CAPC1005X60" urn="urn:adsk.eagle:footprint:16290849/5" library_version="24">
<description>Chip, 1.00 X 0.50 X 0.60 mm body
&lt;p&gt;Chip package with body size 1.00 X 0.50 X 0.60 mm&lt;/p&gt;</description>
<wire x1="0.55" y1="0.6286" x2="-0.55" y2="0.6286" width="0.127" layer="21"/>
<wire x1="0.55" y1="-0.6286" x2="-0.55" y2="-0.6286" width="0.127" layer="21"/>
<wire x1="0.55" y1="-0.3" x2="-0.55" y2="-0.3" width="0.12" layer="51"/>
<wire x1="-0.55" y1="-0.3" x2="-0.55" y2="0.3" width="0.12" layer="51"/>
<wire x1="-0.55" y1="0.3" x2="0.55" y2="0.3" width="0.12" layer="51"/>
<wire x1="0.55" y1="0.3" x2="0.55" y2="-0.3" width="0.12" layer="51"/>
<smd name="1" x="-0.4846" y="0" dx="0.56" dy="0.6291" layer="1"/>
<smd name="2" x="0.4846" y="0" dx="0.56" dy="0.6291" layer="1"/>
<text x="0" y="1.2636" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-1.2636" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPC1110X102" urn="urn:adsk.eagle:footprint:16290845/5" library_version="24">
<description>Chip, 1.17 X 1.02 X 1.02 mm body
&lt;p&gt;Chip package with body size 1.17 X 1.02 X 1.02 mm&lt;/p&gt;</description>
<wire x1="0.66" y1="0.9552" x2="-0.66" y2="0.9552" width="0.127" layer="21"/>
<wire x1="0.66" y1="-0.9552" x2="-0.66" y2="-0.9552" width="0.127" layer="21"/>
<wire x1="0.66" y1="-0.635" x2="-0.66" y2="-0.635" width="0.12" layer="51"/>
<wire x1="-0.66" y1="-0.635" x2="-0.66" y2="0.635" width="0.12" layer="51"/>
<wire x1="-0.66" y1="0.635" x2="0.66" y2="0.635" width="0.12" layer="51"/>
<wire x1="0.66" y1="0.635" x2="0.66" y2="-0.635" width="0.12" layer="51"/>
<smd name="1" x="-0.5388" y="0" dx="0.6626" dy="1.2823" layer="1"/>
<smd name="2" x="0.5388" y="0" dx="0.6626" dy="1.2823" layer="1"/>
<text x="0" y="1.5902" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-1.5902" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPC1608X85" urn="urn:adsk.eagle:footprint:16290847/5" library_version="24">
<description>Chip, 1.60 X 0.80 X 0.85 mm body
&lt;p&gt;Chip package with body size 1.60 X 0.80 X 0.85 mm&lt;/p&gt;</description>
<wire x1="0.875" y1="0.7991" x2="-0.875" y2="0.7991" width="0.127" layer="21"/>
<wire x1="0.875" y1="-0.7991" x2="-0.875" y2="-0.7991" width="0.127" layer="21"/>
<wire x1="0.875" y1="-0.475" x2="-0.875" y2="-0.475" width="0.12" layer="51"/>
<wire x1="-0.875" y1="-0.475" x2="-0.875" y2="0.475" width="0.12" layer="51"/>
<wire x1="-0.875" y1="0.475" x2="0.875" y2="0.475" width="0.12" layer="51"/>
<wire x1="0.875" y1="0.475" x2="0.875" y2="-0.475" width="0.12" layer="51"/>
<smd name="1" x="-0.7746" y="0" dx="0.9209" dy="0.9702" layer="1"/>
<smd name="2" x="0.7746" y="0" dx="0.9209" dy="0.9702" layer="1"/>
<text x="0" y="1.4341" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-1.4341" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPC2012X110" urn="urn:adsk.eagle:footprint:16290848/5" library_version="24">
<description>Chip, 2.00 X 1.25 X 1.10 mm body
&lt;p&gt;Chip package with body size 2.00 X 1.25 X 1.10 mm&lt;/p&gt;</description>
<wire x1="1.1" y1="1.0467" x2="-1.1" y2="1.0467" width="0.127" layer="21"/>
<wire x1="1.1" y1="-1.0467" x2="-1.1" y2="-1.0467" width="0.127" layer="21"/>
<wire x1="1.1" y1="-0.725" x2="-1.1" y2="-0.725" width="0.12" layer="51"/>
<wire x1="-1.1" y1="-0.725" x2="-1.1" y2="0.725" width="0.12" layer="51"/>
<wire x1="-1.1" y1="0.725" x2="1.1" y2="0.725" width="0.12" layer="51"/>
<wire x1="1.1" y1="0.725" x2="1.1" y2="-0.725" width="0.12" layer="51"/>
<smd name="1" x="-0.8754" y="0" dx="1.1646" dy="1.4653" layer="1"/>
<smd name="2" x="0.8754" y="0" dx="1.1646" dy="1.4653" layer="1"/>
<text x="0" y="1.6817" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-1.6817" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPC3216X135" urn="urn:adsk.eagle:footprint:16290836/5" library_version="24">
<description>Chip, 3.20 X 1.60 X 1.35 mm body
&lt;p&gt;Chip package with body size 3.20 X 1.60 X 1.35 mm&lt;/p&gt;</description>
<wire x1="1.7" y1="1.2217" x2="-1.7" y2="1.2217" width="0.127" layer="21"/>
<wire x1="1.7" y1="-1.2217" x2="-1.7" y2="-1.2217" width="0.127" layer="21"/>
<wire x1="1.7" y1="-0.9" x2="-1.7" y2="-0.9" width="0.12" layer="51"/>
<wire x1="-1.7" y1="-0.9" x2="-1.7" y2="0.9" width="0.12" layer="51"/>
<wire x1="-1.7" y1="0.9" x2="1.7" y2="0.9" width="0.12" layer="51"/>
<wire x1="1.7" y1="0.9" x2="1.7" y2="-0.9" width="0.12" layer="51"/>
<smd name="1" x="-1.4754" y="0" dx="1.1646" dy="1.8153" layer="1"/>
<smd name="2" x="1.4754" y="0" dx="1.1646" dy="1.8153" layer="1"/>
<text x="0" y="1.8567" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-1.8567" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPC3225X135" urn="urn:adsk.eagle:footprint:16290843/5" library_version="24">
<description>Chip, 3.20 X 2.50 X 1.35 mm body
&lt;p&gt;Chip package with body size 3.20 X 2.50 X 1.35 mm&lt;/p&gt;</description>
<wire x1="1.7" y1="1.6717" x2="-1.7" y2="1.6717" width="0.127" layer="21"/>
<wire x1="1.7" y1="-1.6717" x2="-1.7" y2="-1.6717" width="0.12" layer="21"/>
<wire x1="1.7" y1="-1.35" x2="-1.7" y2="-1.35" width="0.12" layer="51"/>
<wire x1="-1.7" y1="-1.35" x2="-1.7" y2="1.35" width="0.12" layer="51"/>
<wire x1="-1.7" y1="1.35" x2="1.7" y2="1.35" width="0.12" layer="51"/>
<wire x1="1.7" y1="1.35" x2="1.7" y2="-1.35" width="0.12" layer="51"/>
<smd name="1" x="-1.4754" y="0" dx="1.1646" dy="2.7153" layer="1"/>
<smd name="2" x="1.4754" y="0" dx="1.1646" dy="2.7153" layer="1"/>
<text x="0" y="2.3067" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-2.3067" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPC4532X135" urn="urn:adsk.eagle:footprint:16290841/5" library_version="24">
<description>Chip, 4.50 X 3.20 X 1.35 mm body
&lt;p&gt;Chip package with body size 4.50 X 3.20 X 1.35 mm&lt;/p&gt;</description>
<wire x1="2.4" y1="2.0217" x2="-2.4" y2="2.0217" width="0.127" layer="21"/>
<wire x1="2.4" y1="-2.0217" x2="-2.4" y2="-2.0217" width="0.127" layer="21"/>
<wire x1="2.4" y1="-1.7" x2="-2.4" y2="-1.7" width="0.12" layer="51"/>
<wire x1="-2.4" y1="-1.7" x2="-2.4" y2="1.7" width="0.12" layer="51"/>
<wire x1="-2.4" y1="1.7" x2="2.4" y2="1.7" width="0.12" layer="51"/>
<wire x1="2.4" y1="1.7" x2="2.4" y2="-1.7" width="0.12" layer="51"/>
<smd name="1" x="-2.0565" y="0" dx="1.3973" dy="3.4153" layer="1"/>
<smd name="2" x="2.0565" y="0" dx="1.3973" dy="3.4153" layer="1"/>
<text x="0" y="2.6567" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-2.6567" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPM3216X180" urn="urn:adsk.eagle:footprint:16290835/5" library_version="24">
<description>Molded Body, 3.20 X 1.60 X 1.80 mm body
&lt;p&gt;Molded Body package with body size 3.20 X 1.60 X 1.80 mm&lt;/p&gt;</description>
<wire x1="-1.7" y1="0.9084" x2="1.7" y2="0.9084" width="0.127" layer="21"/>
<wire x1="-1.7" y1="-0.9084" x2="1.7" y2="-0.9084" width="0.127" layer="21"/>
<wire x1="1.7" y1="-0.9" x2="-1.7" y2="-0.9" width="0.12" layer="51"/>
<wire x1="-1.7" y1="-0.9" x2="-1.7" y2="0.9" width="0.12" layer="51"/>
<wire x1="-1.7" y1="0.9" x2="1.7" y2="0.9" width="0.12" layer="51"/>
<wire x1="1.7" y1="0.9" x2="1.7" y2="-0.9" width="0.12" layer="51"/>
<smd name="1" x="-1.3099" y="0" dx="1.7955" dy="1.1887" layer="1"/>
<smd name="2" x="1.3099" y="0" dx="1.7955" dy="1.1887" layer="1"/>
<text x="0" y="1.5434" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-1.5434" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPM3528X210" urn="urn:adsk.eagle:footprint:16290844/5" library_version="24">
<description>Molded Body, 3.50 X 2.80 X 2.10 mm body
&lt;p&gt;Molded Body package with body size 3.50 X 2.80 X 2.10 mm&lt;/p&gt;</description>
<wire x1="-1.85" y1="1.5" x2="1.85" y2="1.5" width="0.127" layer="21"/>
<wire x1="-1.85" y1="-1.5" x2="1.85" y2="-1.5" width="0.127" layer="21"/>
<wire x1="1.85" y1="-1.5" x2="-1.85" y2="-1.5" width="0.12" layer="51"/>
<wire x1="-1.85" y1="-1.5" x2="-1.85" y2="1.5" width="0.12" layer="51"/>
<wire x1="-1.85" y1="1.5" x2="1.85" y2="1.5" width="0.12" layer="51"/>
<wire x1="1.85" y1="1.5" x2="1.85" y2="-1.5" width="0.12" layer="51"/>
<smd name="1" x="-1.4599" y="0" dx="1.7955" dy="2.2036" layer="1"/>
<smd name="2" x="1.4599" y="0" dx="1.7955" dy="2.2036" layer="1"/>
<text x="0" y="2.135" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-2.135" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPM6032X280" urn="urn:adsk.eagle:footprint:16290839/5" library_version="24">
<description>Molded Body, 6.00 X 3.20 X 2.80 mm body
&lt;p&gt;Molded Body package with body size 6.00 X 3.20 X 2.80 mm&lt;/p&gt;</description>
<wire x1="-3.15" y1="1.75" x2="3.15" y2="1.75" width="0.127" layer="21"/>
<wire x1="-3.15" y1="-1.75" x2="3.15" y2="-1.75" width="0.127" layer="21"/>
<wire x1="3.15" y1="-1.75" x2="-3.15" y2="-1.75" width="0.12" layer="51"/>
<wire x1="-3.15" y1="-1.75" x2="-3.15" y2="1.75" width="0.12" layer="51"/>
<wire x1="-3.15" y1="1.75" x2="3.15" y2="1.75" width="0.12" layer="51"/>
<wire x1="3.15" y1="1.75" x2="3.15" y2="-1.75" width="0.12" layer="51"/>
<smd name="1" x="-2.4712" y="0" dx="2.368" dy="2.2036" layer="1"/>
<smd name="2" x="2.4712" y="0" dx="2.368" dy="2.2036" layer="1"/>
<text x="0" y="2.385" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-2.385" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPM7343X310" urn="urn:adsk.eagle:footprint:16290840/5" library_version="24">
<description>Molded Body, 7.30 X 4.30 X 3.10 mm body
&lt;p&gt;Molded Body package with body size 7.30 X 4.30 X 3.10 mm&lt;/p&gt;</description>
<wire x1="-3.8" y1="2.3" x2="3.8" y2="2.3" width="0.127" layer="21"/>
<wire x1="-3.8" y1="-2.3" x2="3.8" y2="-2.3" width="0.127" layer="21"/>
<wire x1="3.8" y1="-2.3" x2="-3.8" y2="-2.3" width="0.12" layer="51"/>
<wire x1="-3.8" y1="-2.3" x2="-3.8" y2="2.3" width="0.12" layer="51"/>
<wire x1="-3.8" y1="2.3" x2="3.8" y2="2.3" width="0.12" layer="51"/>
<wire x1="3.8" y1="2.3" x2="3.8" y2="-2.3" width="0.12" layer="51"/>
<smd name="1" x="-3.1212" y="0" dx="2.368" dy="2.4036" layer="1"/>
<smd name="2" x="3.1212" y="0" dx="2.368" dy="2.4036" layer="1"/>
<text x="0" y="2.935" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-2.935" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPC4564X110" urn="urn:adsk.eagle:footprint:16290837/5" library_version="24">
<description>Chip, 4.50 X 6.40 X 1.10 mm body
&lt;p&gt;Chip package with body size 4.50 X 6.40 X 1.10 mm&lt;/p&gt;</description>
<wire x1="2.4" y1="3.7179" x2="-2.4" y2="3.7179" width="0.127" layer="21"/>
<wire x1="2.4" y1="-3.7179" x2="-2.4" y2="-3.7179" width="0.127" layer="21"/>
<wire x1="2.4" y1="-3.4" x2="-2.4" y2="-3.4" width="0.12" layer="51"/>
<wire x1="-2.4" y1="-3.4" x2="-2.4" y2="3.4" width="0.12" layer="51"/>
<wire x1="-2.4" y1="3.4" x2="2.4" y2="3.4" width="0.12" layer="51"/>
<wire x1="2.4" y1="3.4" x2="2.4" y2="-3.4" width="0.12" layer="51"/>
<smd name="1" x="-2.0565" y="0" dx="1.3973" dy="6.8078" layer="1"/>
<smd name="2" x="2.0565" y="0" dx="1.3973" dy="6.8078" layer="1"/>
<text x="0" y="4.3529" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-4.3529" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPRD550W60D1025H1250B" urn="urn:adsk.eagle:footprint:16290829/5" library_version="24">
<description>Radial Non-Polarized Capacitor, 5.50 mm pitch, 10.25 mm body diameter, 12.50 mm body height
&lt;p&gt;Radial Non-Polarized Capacitor package with 5.50 mm pitch (lead spacing), 0.60 mm lead diameter, 10.25 mm body diameter and 12.50 mm body height&lt;/p&gt;</description>
<circle x="0" y="0" radius="5.25" width="0.127" layer="21"/>
<circle x="0" y="0" radius="5.25" width="0.12" layer="51"/>
<pad name="1" x="-2.75" y="0" drill="0.8" diameter="1.4"/>
<pad name="2" x="2.75" y="0" drill="0.8" diameter="1.4"/>
<text x="0" y="5.885" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-5.885" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
<package name="CAPRD2261W240D5080H5555B" urn="urn:adsk.eagle:footprint:16290850/5" library_version="24">
<description>Radial Non-Polarized Capacitor, 22.61 mm pitch, 50.80 mm body diameter, 55.55 mm body height
&lt;p&gt;Radial Non-Polarized Capacitor package with 22.61 mm pitch (lead spacing), 2.40 mm lead diameter, 50.80 mm body diameter and 55.55 mm body height&lt;/p&gt;</description>
<circle x="0" y="0" radius="25.79" width="0.127" layer="21"/>
<circle x="0" y="0" radius="25.79" width="0.12" layer="51"/>
<pad name="1" x="-11.305" y="0" drill="2.6" diameter="3.9"/>
<pad name="2" x="11.305" y="0" drill="2.6" diameter="3.9"/>
<text x="0" y="26.425" size="1.27" layer="25" align="bottom-center">&gt;NAME</text>
<text x="0" y="-26.425" size="1.27" layer="27" align="top-center">&gt;VALUE</text>
</package>
</packages>
<packages3d>
<package3d name="CAPC1005X60" urn="urn:adsk.eagle:package:16290895/5" type="model">
<description>Chip, 1.00 X 0.50 X 0.60 mm body
&lt;p&gt;Chip package with body size 1.00 X 0.50 X 0.60 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC1005X60"/>
</packageinstances>
</package3d>
<package3d name="CAPC1110X102" urn="urn:adsk.eagle:package:16290904/5" type="model">
<description>Chip, 1.17 X 1.02 X 1.02 mm body
&lt;p&gt;Chip package with body size 1.17 X 1.02 X 1.02 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC1110X102"/>
</packageinstances>
</package3d>
<package3d name="CAPC1608X85" urn="urn:adsk.eagle:package:16290898/5" type="model">
<description>Chip, 1.60 X 0.80 X 0.85 mm body
&lt;p&gt;Chip package with body size 1.60 X 0.80 X 0.85 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC1608X85"/>
</packageinstances>
</package3d>
<package3d name="CAPC2012X110" urn="urn:adsk.eagle:package:16290897/5" type="model">
<description>Chip, 2.00 X 1.25 X 1.10 mm body
&lt;p&gt;Chip package with body size 2.00 X 1.25 X 1.10 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC2012X110"/>
</packageinstances>
</package3d>
<package3d name="CAPC3216X135" urn="urn:adsk.eagle:package:16290893/5" type="model">
<description>Chip, 3.20 X 1.60 X 1.35 mm body
&lt;p&gt;Chip package with body size 3.20 X 1.60 X 1.35 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC3216X135"/>
</packageinstances>
</package3d>
<package3d name="CAPC3225X135" urn="urn:adsk.eagle:package:16290903/5" type="model">
<description>Chip, 3.20 X 2.50 X 1.35 mm body
&lt;p&gt;Chip package with body size 3.20 X 2.50 X 1.35 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC3225X135"/>
</packageinstances>
</package3d>
<package3d name="CAPC4532X135" urn="urn:adsk.eagle:package:16290900/5" type="model">
<description>Chip, 4.50 X 3.20 X 1.35 mm body
&lt;p&gt;Chip package with body size 4.50 X 3.20 X 1.35 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC4532X135"/>
</packageinstances>
</package3d>
<package3d name="CAPM3216X180" urn="urn:adsk.eagle:package:16290894/5" type="model">
<description>Molded Body, 3.20 X 1.60 X 1.80 mm body
&lt;p&gt;Molded Body package with body size 3.20 X 1.60 X 1.80 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPM3216X180"/>
</packageinstances>
</package3d>
<package3d name="CAPM3528X210" urn="urn:adsk.eagle:package:16290902/5" type="model">
<description>Molded Body, 3.50 X 2.80 X 2.10 mm body
&lt;p&gt;Molded Body package with body size 3.50 X 2.80 X 2.10 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPM3528X210"/>
</packageinstances>
</package3d>
<package3d name="CAPM6032X280" urn="urn:adsk.eagle:package:16290896/5" type="model">
<description>Molded Body, 6.00 X 3.20 X 2.80 mm body
&lt;p&gt;Molded Body package with body size 6.00 X 3.20 X 2.80 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPM6032X280"/>
</packageinstances>
</package3d>
<package3d name="CAPM7343X310" urn="urn:adsk.eagle:package:16290891/5" type="model">
<description>Molded Body, 7.30 X 4.30 X 3.10 mm body
&lt;p&gt;Molded Body package with body size 7.30 X 4.30 X 3.10 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPM7343X310"/>
</packageinstances>
</package3d>
<package3d name="CAPC4564X110L" urn="urn:adsk.eagle:package:16290887/6" type="model">
<description>Chip, 4.50 X 6.40 X 1.10 mm body
&lt;p&gt;Chip package with body size 4.50 X 6.40 X 1.10 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPC4564X110"/>
</packageinstances>
</package3d>
<package3d name="CAPRD550W60D1025H1250B" urn="urn:adsk.eagle:package:16290858/5" type="model">
<description>Radial Non-Polarized Capacitor, 5.50 mm pitch, 10.25 mm body diameter, 12.50 mm body height
&lt;p&gt;Radial Non-Polarized Capacitor package with 5.50 mm pitch (lead spacing), 0.60 mm lead diameter, 10.25 mm body diameter and 12.50 mm body height&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPRD550W60D1025H1250B"/>
</packageinstances>
</package3d>
<package3d name="CAPRD2261W240D5080H5555B" urn="urn:adsk.eagle:package:16290864/5" type="model">
<description>Radial Non-Polarized Capacitor, 22.61 mm pitch, 50.80 mm body diameter, 55.55 mm body height
&lt;p&gt;Radial Non-Polarized Capacitor package with 22.61 mm pitch (lead spacing), 2.40 mm lead diameter, 50.80 mm body diameter and 55.55 mm body height&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="CAPRD2261W240D5080H5555B"/>
</packageinstances>
</package3d>
</packages3d>
<symbols>
<symbol name="GND" urn="urn:adsk.eagle:symbol:16997206/1" library_version="24">
<description>Ground (GND) Arrow</description>
<wire x1="-1.27" y1="0" x2="1.27" y2="0" width="0.254" layer="94"/>
<wire x1="1.27" y1="0" x2="0" y2="-1.27" width="0.254" layer="94"/>
<wire x1="0" y1="-1.27" x2="-1.27" y2="0" width="0.254" layer="94"/>
<text x="0.127" y="-3.175" size="1.778" layer="96" align="bottom-center">&gt;VALUE</text>
<pin name="GND" x="0" y="2.54" visible="off" length="short" direction="sup" rot="R270"/>
</symbol>
<symbol name="C" urn="urn:adsk.eagle:symbol:16997215/1" library_version="24">
<description>Capacitor</description>
<rectangle x1="-2.032" y1="-2.032" x2="2.032" y2="-1.524" layer="94"/>
<rectangle x1="-2.032" y1="-1.016" x2="2.032" y2="-0.508" layer="94"/>
<wire x1="0" y1="0" x2="0" y2="-0.508" width="0.1524" layer="94"/>
<wire x1="0" y1="-2.54" x2="0" y2="-2.032" width="0.1524" layer="94"/>
<pin name="1" x="0" y="2.54" visible="off" length="short" direction="pas" swaplevel="1" rot="R270"/>
<pin name="2" x="0" y="-5.08" visible="off" length="short" direction="pas" swaplevel="1" rot="R90"/>
<text x="2.54" y="2.54" size="1.778" layer="95">&gt;NAME</text>
<text x="2.54" y="-2.54" size="1.778" layer="97">&gt;SPICEMODEL</text>
<text x="2.54" y="0" size="1.778" layer="96">&gt;VALUE</text>
<text x="2.54" y="-5.08" size="1.778" layer="97">&gt;SPICEEXTRA</text>
</symbol>
</symbols>
<devicesets>
<deviceset name="GND" urn="urn:adsk.eagle:component:16997230/4" prefix="SUPPLY" uservalue="yes" library_version="24">
<description>&lt;b&gt;SUPPLY SYMBOL&lt;/b&gt; - Ground (GND) Arrow</description>
<gates>
<gate name="G$1" symbol="GND" x="0" y="0"/>
</gates>
<devices>
<device name="">
<technologies>
<technology name="">
<attribute name="CATEGORY" value="Supply" constant="no"/>
<attribute name="VALUE" value="GND" constant="no"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="C" urn="urn:adsk.eagle:component:16997223/6" prefix="C" uservalue="yes" library_version="24">
<description>&lt;B&gt;Capacitor - Generic</description>
<gates>
<gate name="G$1" symbol="C" x="0" y="0"/>
</gates>
<devices>
<device name="CHIP-0402(1005-METRIC)" package="CAPC1005X60">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290895/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-0504(1310-METRIC)" package="CAPC1110X102">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290904/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-0603(1608-METRIC)" package="CAPC1608X85">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290898/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-0805(2012-METRIC)" package="CAPC2012X110">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290897/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1206(3216-METRIC)" package="CAPC3216X135">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290893/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1210(3225-METRIC)" package="CAPC3225X135">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290903/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1812(4532-METRIC)" package="CAPC4532X135">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290900/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="TANTALUM-1206(3216-METRIC)" package="CAPM3216X180">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290894/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="TANTALUM-1411(3528-METRIC)" package="CAPM3528X210">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290902/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="TANTALUM-2412(6032-METRIC)" package="CAPM6032X280">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290896/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="TANTALUM-2917(7343-METRIC)" package="CAPM7343X310">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290891/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1825(4564-METRIC)" package="CAPC4564X110">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290887/6"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="RADIAL-12.5MM-DIA" package="CAPRD550W60D1025H1250B">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290858/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
<device name="RADIAL-55.5MM-DIA" package="CAPRD2261W240D5080H5555B">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16290864/5"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Capacitor" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMP" value="" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS_COMPLIANT" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUB-CATEGORY" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="VOLTAGE_RATING" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
</technology>
</technologies>
</device>
</devices>
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
</deviceset>
</devicesets>
</library>
<library name="Resistor" urn="urn:adsk.eagle:library:16378527">
<description>Resistors, Potentiometers, TrimPot</description>
<packages>
<package name="RESC1005X40" urn="urn:adsk.eagle:footprint:16378540/6" library_version="26">
<description>Chip, 1.05 X 0.54 X 0.40 mm body
&lt;p&gt;Chip package with body size 1.05 X 0.54 X 0.40 mm&lt;/p&gt;</description>
<wire x1="0.55" y1="0.636" x2="-0.55" y2="0.636" width="0.127" layer="21"/>
<wire x1="0.55" y1="-0.636" x2="-0.55" y2="-0.636" width="0.127" layer="21"/>
<wire x1="0.55" y1="-0.3" x2="-0.55" y2="-0.3" width="0.12" layer="51"/>
<wire x1="-0.55" y1="-0.3" x2="-0.55" y2="0.3" width="0.12" layer="51"/>
<wire x1="-0.55" y1="0.3" x2="0.55" y2="0.3" width="0.12" layer="51"/>
<wire x1="0.55" y1="0.3" x2="0.55" y2="-0.3" width="0.12" layer="51"/>
<smd name="1" x="-0.5075" y="0" dx="0.5351" dy="0.644" layer="1"/>
<smd name="2" x="0.5075" y="0" dx="0.5351" dy="0.644" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="RESC1608X60" urn="urn:adsk.eagle:footprint:16378537/6" library_version="26">
<description>Chip, 1.60 X 0.82 X 0.60 mm body
&lt;p&gt;Chip package with body size 1.60 X 0.82 X 0.60 mm&lt;/p&gt;</description>
<wire x1="0.85" y1="0.8009" x2="-0.85" y2="0.8009" width="0.127" layer="21"/>
<wire x1="0.85" y1="-0.8009" x2="-0.85" y2="-0.8009" width="0.127" layer="21"/>
<wire x1="0.85" y1="-0.475" x2="-0.85" y2="-0.475" width="0.12" layer="51"/>
<wire x1="-0.85" y1="-0.475" x2="-0.85" y2="0.475" width="0.12" layer="51"/>
<wire x1="-0.85" y1="0.475" x2="0.85" y2="0.475" width="0.12" layer="51"/>
<wire x1="0.85" y1="0.475" x2="0.85" y2="-0.475" width="0.12" layer="51"/>
<smd name="1" x="-0.8152" y="0" dx="0.7987" dy="0.9739" layer="1"/>
<smd name="2" x="0.8152" y="0" dx="0.7987" dy="0.9739" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="RESC2012X65" urn="urn:adsk.eagle:footprint:16378532/6" library_version="26">
<description>Chip, 2.00 X 1.25 X 0.65 mm body
&lt;p&gt;Chip package with body size 2.00 X 1.25 X 0.65 mm&lt;/p&gt;</description>
<wire x1="1.075" y1="1.0241" x2="-1.075" y2="1.0241" width="0.127" layer="21"/>
<wire x1="1.075" y1="-1.0241" x2="-1.075" y2="-1.0241" width="0.127" layer="21"/>
<wire x1="1.075" y1="-0.7" x2="-1.075" y2="-0.7" width="0.12" layer="51"/>
<wire x1="-1.075" y1="-0.7" x2="-1.075" y2="0.7" width="0.12" layer="51"/>
<wire x1="-1.075" y1="0.7" x2="1.075" y2="0.7" width="0.12" layer="51"/>
<wire x1="1.075" y1="0.7" x2="1.075" y2="-0.7" width="0.12" layer="51"/>
<smd name="1" x="-0.9195" y="0" dx="1.0312" dy="1.4202" layer="1"/>
<smd name="2" x="0.9195" y="0" dx="1.0312" dy="1.4202" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="RESC3216X70" urn="urn:adsk.eagle:footprint:16378539/6" library_version="26">
<description>Chip, 3.20 X 1.60 X 0.70 mm body
&lt;p&gt;Chip package with body size 3.20 X 1.60 X 0.70 mm&lt;/p&gt;</description>
<wire x1="1.7" y1="1.2217" x2="-1.7" y2="1.2217" width="0.127" layer="21"/>
<wire x1="1.7" y1="-1.2217" x2="-1.7" y2="-1.2217" width="0.127" layer="21"/>
<wire x1="1.7" y1="-0.9" x2="-1.7" y2="-0.9" width="0.12" layer="51"/>
<wire x1="-1.7" y1="-0.9" x2="-1.7" y2="0.9" width="0.12" layer="51"/>
<wire x1="-1.7" y1="0.9" x2="1.7" y2="0.9" width="0.12" layer="51"/>
<wire x1="1.7" y1="0.9" x2="1.7" y2="-0.9" width="0.12" layer="51"/>
<smd name="1" x="-1.4754" y="0" dx="1.1646" dy="1.8153" layer="1"/>
<smd name="2" x="1.4754" y="0" dx="1.1646" dy="1.8153" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="RESC3224X71" urn="urn:adsk.eagle:footprint:16378536/6" library_version="26">
<description>Chip, 3.20 X 2.49 X 0.71 mm body
&lt;p&gt;Chip package with body size 3.20 X 2.49 X 0.71 mm&lt;/p&gt;</description>
<wire x1="1.675" y1="1.6441" x2="-1.675" y2="1.6441" width="0.127" layer="21"/>
<wire x1="1.675" y1="-1.6441" x2="-1.675" y2="-1.6441" width="0.127" layer="21"/>
<wire x1="1.675" y1="-1.32" x2="-1.675" y2="-1.32" width="0.12" layer="51"/>
<wire x1="-1.675" y1="-1.32" x2="-1.675" y2="1.32" width="0.12" layer="51"/>
<wire x1="-1.675" y1="1.32" x2="1.675" y2="1.32" width="0.12" layer="51"/>
<wire x1="1.675" y1="1.32" x2="1.675" y2="-1.32" width="0.12" layer="51"/>
<smd name="1" x="-1.4695" y="0" dx="1.1312" dy="2.6602" layer="1"/>
<smd name="2" x="1.4695" y="0" dx="1.1312" dy="2.6602" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="RESC5025X71" urn="urn:adsk.eagle:footprint:16378538/6" library_version="26">
<description>Chip, 5.00 X 2.50 X 0.71 mm body
&lt;p&gt;Chip package with body size 5.00 X 2.50 X 0.71 mm&lt;/p&gt;</description>
<wire x1="2.575" y1="1.6491" x2="-2.575" y2="1.6491" width="0.127" layer="21"/>
<wire x1="2.575" y1="-1.6491" x2="-2.575" y2="-1.6491" width="0.127" layer="21"/>
<wire x1="2.575" y1="-1.325" x2="-2.575" y2="-1.325" width="0.12" layer="51"/>
<wire x1="-2.575" y1="-1.325" x2="-2.575" y2="1.325" width="0.12" layer="51"/>
<wire x1="-2.575" y1="1.325" x2="2.575" y2="1.325" width="0.12" layer="51"/>
<wire x1="2.575" y1="1.325" x2="2.575" y2="-1.325" width="0.12" layer="51"/>
<smd name="1" x="-2.3195" y="0" dx="1.2312" dy="2.6702" layer="1"/>
<smd name="2" x="2.3195" y="0" dx="1.2312" dy="2.6702" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="RESC6332X71" urn="urn:adsk.eagle:footprint:16378533/6" library_version="26">
<description>Chip, 6.30 X 3.20 X 0.71 mm body
&lt;p&gt;Chip package with body size 6.30 X 3.20 X 0.71 mm&lt;/p&gt;</description>
<wire x1="3.225" y1="1.9991" x2="-3.225" y2="1.9991" width="0.127" layer="21"/>
<wire x1="3.225" y1="-1.9991" x2="-3.225" y2="-1.9991" width="0.127" layer="21"/>
<wire x1="3.225" y1="-1.675" x2="-3.225" y2="-1.675" width="0.12" layer="51"/>
<wire x1="-3.225" y1="-1.675" x2="-3.225" y2="1.675" width="0.12" layer="51"/>
<wire x1="-3.225" y1="1.675" x2="3.225" y2="1.675" width="0.12" layer="51"/>
<wire x1="3.225" y1="1.675" x2="3.225" y2="-1.675" width="0.12" layer="51"/>
<smd name="1" x="-2.9695" y="0" dx="1.2312" dy="3.3702" layer="1"/>
<smd name="2" x="2.9695" y="0" dx="1.2312" dy="3.3702" layer="1"/>
<text x="0" y="3.81" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-3.81" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="RESAD1176W63L850D250B" urn="urn:adsk.eagle:footprint:16378542/6" library_version="26">
<description>AXIAL Resistor, 11.76 mm pitch, 8.5 mm body length, 2.5 mm body diameter
&lt;p&gt;AXIAL Resistor package with 11.76 mm pitch, 0.63 mm lead diameter, 8.5 mm body length and 2.5 mm body diameter&lt;/p&gt;</description>
<wire x1="-4.25" y1="1.25" x2="-4.25" y2="-1.25" width="0.127" layer="21"/>
<wire x1="-4.25" y1="-1.25" x2="4.25" y2="-1.25" width="0.127" layer="21"/>
<wire x1="4.25" y1="-1.25" x2="4.25" y2="1.25" width="0.127" layer="21"/>
<wire x1="4.25" y1="1.25" x2="-4.25" y2="1.25" width="0.127" layer="21"/>
<wire x1="-4.25" y1="0" x2="-4.911" y2="0" width="0.127" layer="21"/>
<wire x1="4.25" y1="0" x2="4.911" y2="0" width="0.127" layer="21"/>
<wire x1="4.25" y1="-1.25" x2="-4.25" y2="-1.25" width="0.12" layer="51"/>
<wire x1="-4.25" y1="-1.25" x2="-4.25" y2="1.25" width="0.12" layer="51"/>
<wire x1="-4.25" y1="1.25" x2="4.25" y2="1.25" width="0.12" layer="51"/>
<wire x1="4.25" y1="1.25" x2="4.25" y2="-1.25" width="0.12" layer="51"/>
<pad name="1" x="-5.88" y="0" drill="0.83" diameter="1.43"/>
<pad name="2" x="5.88" y="0" drill="0.83" diameter="1.43"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="RESMELF3515" urn="urn:adsk.eagle:footprint:16378534/6" library_version="26">
<description>MELF, 3.50 mm length, 1.52 mm diameter
&lt;p&gt;MELF Resistor package with 3.50 mm length and 1.52 mm diameter&lt;/p&gt;</description>
<wire x1="1.105" y1="1.1825" x2="-1.105" y2="1.1825" width="0.127" layer="21"/>
<wire x1="-1.105" y1="-1.1825" x2="1.105" y2="-1.1825" width="0.127" layer="21"/>
<wire x1="1.85" y1="-0.8" x2="-1.85" y2="-0.8" width="0.12" layer="51"/>
<wire x1="-1.85" y1="-0.8" x2="-1.85" y2="0.8" width="0.12" layer="51"/>
<wire x1="-1.85" y1="0.8" x2="1.85" y2="0.8" width="0.12" layer="51"/>
<wire x1="1.85" y1="0.8" x2="1.85" y2="-0.8" width="0.12" layer="51"/>
<smd name="1" x="-1.6813" y="0" dx="1.1527" dy="1.7371" layer="1"/>
<smd name="2" x="1.6813" y="0" dx="1.1527" dy="1.7371" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="RESMELF2014" urn="urn:adsk.eagle:footprint:16378535/6" library_version="26">
<description>MELF, 2.00 mm length, 1.40 mm diameter
&lt;p&gt;MELF Resistor package with 2.00 mm length and 1.40 mm diameter&lt;/p&gt;</description>
<wire x1="0.5189" y1="1.114" x2="-0.5189" y2="1.114" width="0.127" layer="21"/>
<wire x1="-0.5189" y1="-1.114" x2="0.5189" y2="-1.114" width="0.127" layer="21"/>
<wire x1="1.05" y1="-0.725" x2="-1.05" y2="-0.725" width="0.12" layer="51"/>
<wire x1="-1.05" y1="-0.725" x2="-1.05" y2="0.725" width="0.12" layer="51"/>
<wire x1="-1.05" y1="0.725" x2="1.05" y2="0.725" width="0.12" layer="51"/>
<wire x1="1.05" y1="0.725" x2="1.05" y2="-0.725" width="0.12" layer="51"/>
<smd name="1" x="-0.9918" y="0" dx="0.9456" dy="1.6" layer="1"/>
<smd name="2" x="0.9918" y="0" dx="0.9456" dy="1.6" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="RESMELF5924" urn="urn:adsk.eagle:footprint:16378541/6" library_version="26">
<description>MELF, 5.90 mm length, 2.45 mm diameter
&lt;p&gt;MELF Resistor package with 5.90 mm length and 2.45 mm diameter&lt;/p&gt;</description>
<wire x1="2.1315" y1="1.639" x2="-2.1315" y2="1.639" width="0.127" layer="21"/>
<wire x1="-2.1315" y1="-1.639" x2="2.1315" y2="-1.639" width="0.127" layer="21"/>
<wire x1="3.05" y1="-1.25" x2="-3.05" y2="-1.25" width="0.12" layer="51"/>
<wire x1="-3.05" y1="-1.25" x2="-3.05" y2="1.25" width="0.12" layer="51"/>
<wire x1="-3.05" y1="1.25" x2="3.05" y2="1.25" width="0.12" layer="51"/>
<wire x1="3.05" y1="1.25" x2="3.05" y2="-1.25" width="0.12" layer="51"/>
<smd name="1" x="-2.7946" y="0" dx="1.3261" dy="2.65" layer="1"/>
<smd name="2" x="2.7946" y="0" dx="1.3261" dy="2.65" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="RESMELF3218" urn="urn:adsk.eagle:footprint:16378531/6" library_version="26">
<description>MELF, 3.20 mm length, 1.80 mm diameter
&lt;p&gt;MELF Resistor package with 3.20 mm length and 1.80 mm diameter&lt;/p&gt;</description>
<wire x1="0.8815" y1="1.314" x2="-0.8815" y2="1.314" width="0.127" layer="21"/>
<wire x1="-0.8815" y1="-1.314" x2="0.8815" y2="-1.314" width="0.127" layer="21"/>
<wire x1="1.7" y1="-0.925" x2="-1.7" y2="-0.925" width="0.12" layer="51"/>
<wire x1="-1.7" y1="-0.925" x2="-1.7" y2="0.925" width="0.12" layer="51"/>
<wire x1="-1.7" y1="0.925" x2="1.7" y2="0.925" width="0.12" layer="51"/>
<wire x1="1.7" y1="0.925" x2="1.7" y2="-0.925" width="0.12" layer="51"/>
<smd name="1" x="-1.4946" y="0" dx="1.2261" dy="2" layer="1"/>
<smd name="2" x="1.4946" y="0" dx="1.2261" dy="2" layer="1"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="RESAD724W46L381D178B" urn="urn:adsk.eagle:footprint:16378530/6" library_version="26">
<description>Axial Resistor, 7.24 mm pitch, 3.81 mm body length, 1.78 mm body diameter
&lt;p&gt;Axial Resistor package with 7.24 mm pitch (lead spacing), 0.46 mm lead diameter, 3.81 mm body length and 1.78 mm body diameter&lt;/p&gt;</description>
<wire x1="-2.16" y1="1.015" x2="-2.16" y2="-1.015" width="0.127" layer="21"/>
<wire x1="-2.16" y1="-1.015" x2="2.16" y2="-1.015" width="0.127" layer="21"/>
<wire x1="2.16" y1="-1.015" x2="2.16" y2="1.015" width="0.127" layer="21"/>
<wire x1="2.16" y1="1.015" x2="-2.16" y2="1.015" width="0.127" layer="21"/>
<wire x1="-2.16" y1="0" x2="-2.736" y2="0" width="0.127" layer="21"/>
<wire x1="2.16" y1="0" x2="2.736" y2="0" width="0.127" layer="21"/>
<wire x1="2.16" y1="-1.015" x2="-2.16" y2="-1.015" width="0.12" layer="51"/>
<wire x1="-2.16" y1="-1.015" x2="-2.16" y2="1.015" width="0.12" layer="51"/>
<wire x1="-2.16" y1="1.015" x2="2.16" y2="1.015" width="0.12" layer="51"/>
<wire x1="2.16" y1="1.015" x2="2.16" y2="-1.015" width="0.12" layer="51"/>
<pad name="1" x="-3.62" y="0" drill="0.66" diameter="1.26"/>
<pad name="2" x="3.62" y="0" drill="0.66" diameter="1.26"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
</packages>
<packages3d>
<package3d name="RESC1005X40" urn="urn:adsk.eagle:package:16378568/7" type="model">
<description>Chip, 1.05 X 0.54 X 0.40 mm body
&lt;p&gt;Chip package with body size 1.05 X 0.54 X 0.40 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESC1005X40"/>
</packageinstances>
</package3d>
<package3d name="RESC1608X60" urn="urn:adsk.eagle:package:16378565/7" type="model">
<description>Chip, 1.60 X 0.82 X 0.60 mm body
&lt;p&gt;Chip package with body size 1.60 X 0.82 X 0.60 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESC1608X60"/>
</packageinstances>
</package3d>
<package3d name="RESC2012X65" urn="urn:adsk.eagle:package:16378559/7" type="model">
<description>Chip, 2.00 X 1.25 X 0.65 mm body
&lt;p&gt;Chip package with body size 2.00 X 1.25 X 0.65 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESC2012X65"/>
</packageinstances>
</package3d>
<package3d name="RESC3216X70" urn="urn:adsk.eagle:package:16378566/7" type="model">
<description>Chip, 3.20 X 1.60 X 0.70 mm body
&lt;p&gt;Chip package with body size 3.20 X 1.60 X 0.70 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESC3216X70"/>
</packageinstances>
</package3d>
<package3d name="RESC3224X71" urn="urn:adsk.eagle:package:16378563/8" type="model">
<description>Chip, 3.20 X 2.49 X 0.71 mm body
&lt;p&gt;Chip package with body size 3.20 X 2.49 X 0.71 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESC3224X71"/>
</packageinstances>
</package3d>
<package3d name="RESC5025X71" urn="urn:adsk.eagle:package:16378564/7" type="model">
<description>Chip, 5.00 X 2.50 X 0.71 mm body
&lt;p&gt;Chip package with body size 5.00 X 2.50 X 0.71 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESC5025X71"/>
</packageinstances>
</package3d>
<package3d name="RESC6332X71L" urn="urn:adsk.eagle:package:16378557/8" type="model">
<description>Chip, 6.30 X 3.20 X 0.71 mm body
&lt;p&gt;Chip package with body size 6.30 X 3.20 X 0.71 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESC6332X71"/>
</packageinstances>
</package3d>
<package3d name="RESAD1176W63L850D250B" urn="urn:adsk.eagle:package:16378560/7" type="model">
<description>AXIAL Resistor, 11.76 mm pitch, 8.5 mm body length, 2.5 mm body diameter
&lt;p&gt;AXIAL Resistor package with 11.76 mm pitch, 0.63 mm lead diameter, 8.5 mm body length and 2.5 mm body diameter&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESAD1176W63L850D250B"/>
</packageinstances>
</package3d>
<package3d name="RESMELF3515" urn="urn:adsk.eagle:package:16378562/7" type="model">
<description>MELF, 3.50 mm length, 1.52 mm diameter
&lt;p&gt;MELF Resistor package with 3.50 mm length and 1.52 mm diameter&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESMELF3515"/>
</packageinstances>
</package3d>
<package3d name="RESMELF2014" urn="urn:adsk.eagle:package:16378558/7" type="model">
<description>MELF, 2.00 mm length, 1.40 mm diameter
&lt;p&gt;MELF Resistor package with 2.00 mm length and 1.40 mm diameter&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESMELF2014"/>
</packageinstances>
</package3d>
<package3d name="RESMELF5924" urn="urn:adsk.eagle:package:16378567/8" type="model">
<description>MELF, 5.90 mm length, 2.45 mm diameter
&lt;p&gt;MELF Resistor package with 5.90 mm length and 2.45 mm diameter&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESMELF5924"/>
</packageinstances>
</package3d>
<package3d name="RESMELF3218" urn="urn:adsk.eagle:package:16378556/7" type="model">
<description>MELF, 3.20 mm length, 1.80 mm diameter
&lt;p&gt;MELF Resistor package with 3.20 mm length and 1.80 mm diameter&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESMELF3218"/>
</packageinstances>
</package3d>
<package3d name="RESAD724W46L381D178B" urn="urn:adsk.eagle:package:16378561/7" type="model">
<description>Axial Resistor, 7.24 mm pitch, 3.81 mm body length, 1.78 mm body diameter
&lt;p&gt;Axial Resistor package with 7.24 mm pitch (lead spacing), 0.46 mm lead diameter, 3.81 mm body length and 1.78 mm body diameter&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="RESAD724W46L381D178B"/>
</packageinstances>
</package3d>
</packages3d>
<symbols>
<symbol name="R-US" urn="urn:adsk.eagle:symbol:16378528/8" library_version="26">
<description>ANSI‑style: Resistor</description>
<pin name="2" x="5.08" y="0" visible="off" length="short" direction="pas" swaplevel="1" rot="R180"/>
<pin name="1" x="-5.08" y="0" visible="off" length="short" direction="pas" swaplevel="1"/>
<text x="0" y="2.54" size="1.778" layer="95" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.778" layer="96" align="center">&gt;VALUE</text>
<wire x1="-1.143" y1="-1.016" x2="-0.381" y2="1.016" width="0.1524" layer="94"/>
<wire x1="-0.381" y1="1.016" x2="0.381" y2="-1.016" width="0.1524" layer="94"/>
<wire x1="0.381" y1="-1.016" x2="1.143" y2="1.016" width="0.1524" layer="94"/>
<wire x1="1.143" y1="1.016" x2="1.905" y2="-1.016" width="0.1524" layer="94"/>
<wire x1="-1.905" y1="1.016" x2="-1.143" y2="-1.016" width="0.1524" layer="94"/>
<wire x1="-2.286" y1="0" x2="-1.905" y2="1.016" width="0.1524" layer="94"/>
<wire x1="1.905" y1="-1.016" x2="2.286" y2="0" width="0.1524" layer="94"/>
<wire x1="-2.286" y1="0" x2="-2.54" y2="0" width="0.1524" layer="94"/>
<wire x1="2.54" y1="0" x2="2.286" y2="0" width="0.1524" layer="94"/>
</symbol>
<symbol name="R" urn="urn:adsk.eagle:symbol:16378529/8" library_version="26">
<description>IEC‑style: Resistor</description>
<wire x1="-2.54" y1="-0.889" x2="2.54" y2="-0.889" width="0.1524" layer="94"/>
<wire x1="2.54" y1="0.889" x2="-2.54" y2="0.889" width="0.1524" layer="94"/>
<wire x1="2.54" y1="-0.889" x2="2.54" y2="0.889" width="0.1524" layer="94"/>
<wire x1="-2.54" y1="-0.889" x2="-2.54" y2="0.889" width="0.1524" layer="94"/>
<pin name="1" x="-5.08" y="0" visible="off" length="short" direction="pas" swaplevel="1"/>
<pin name="2" x="5.08" y="0" visible="off" length="short" direction="pas" swaplevel="1" rot="R180"/>
<text x="0" y="-5.08" size="1.778" layer="95" align="top-center">&gt;SPICEMODEL</text>
<text x="0" y="-7.62" size="1.778" layer="95" align="top-center">&gt;SPICEEXTRA</text>
<text x="0" y="2.54" size="1.778" layer="95" align="bottom-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.778" layer="96" align="top-center">&gt;VALUE</text>
</symbol>
</symbols>
<devicesets>
<deviceset name="R-US" urn="urn:adsk.eagle:component:16378569/17" prefix="R" uservalue="yes" library_version="26">
<description>Resistor Fixed - ANSI</description>
<gates>
<gate name="G$1" symbol="R-US" x="0" y="0"/>
</gates>
<devices>
<device name="CHIP-0402(1005-METRIC)" package="RESC1005X40">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378568/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 1.05 X 0.54 X 0.40 mm body 0402(1005-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0402" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-0603(1608-METRIC)" package="RESC1608X60">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378565/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 1.60 X 0.82 X 0.60 mm body 0603(1608-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0603" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-0805(2012-METRIC)" package="RESC2012X65">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378559/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 2.00 X 1.25 X 0.65 mm body 0805(2012-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0805" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1206(3216-METRIC)" package="RESC3216X70">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378566/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 3.20 X 1.60 X 0.70 mm body 1206(3216-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1206" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1210(3225-METRIC)" package="RESC3224X71">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378563/8"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 3.20 X 2.49 X 0.71 mm body 1210(3225-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1210" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-2010(5025-METRIC)" package="RESC5025X71">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378564/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 5.00 X 2.50 X 0.71 mm body 2010(5025-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="2010" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-2512(6332-METRIC)" package="RESC6332X71">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378557/8"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 6.30 X 3.20 X 0.71 mm body 2512(6332-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="2512" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="AXIAL-11.7MM-PITCH" package="RESAD1176W63L850D250B">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378560/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Axial Resistor 11.76 mm pitch 8.5 mm body length 2.5 mm body diameter" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="Axial" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Through Hole" constant="no"/>
</technology>
</technologies>
</device>
<device name="MELF(3515-METRIC)" package="RESMELF3515">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378562/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="MELF Resistor 3.50 mm length Resistor 1.52 mm diameter 3515-METRIC Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="MELF" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="MELF(2014-METRIC)" package="RESMELF2014">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378558/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="MELF Resistor 2.00 mm length Resistor 1.40 mm diameter 2014-METRIC Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="MELF" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="MELF(5924-METRIC)" package="RESMELF5924">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378567/8"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="MELF Resistor 5.90 mm length Resistor 2.45 mm diameter 5924-METRIC Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="MELF" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="MELF(3218-METRIC)" package="RESMELF3218">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378556/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="MELF Resistor 3.20 mm length Resistor 1.80 mm diameter 3218-METRIC Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="MELF" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="AXIAL-7.2MM-PITCH" package="RESAD724W46L381D178B">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378561/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Axial Resistor 7.24 mm pitch 3.81 mm body length 1.78 mm body diameter" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="Axial" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Through Hole" constant="no"/>
</technology>
</technologies>
</device>
</devices>
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
</deviceset>
<deviceset name="R" urn="urn:adsk.eagle:component:16378570/15" prefix="R" uservalue="yes" library_version="26">
<description>Resistor Fixed - Generic</description>
<gates>
<gate name="G$1" symbol="R" x="0" y="0"/>
</gates>
<devices>
<device name="CHIP-0402(1005-METRIC)" package="RESC1005X40">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378568/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 1.05 X 0.54 X 0.40 mm body 0402(1005-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0402" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-0603(1608-METRIC)" package="RESC1608X60">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378565/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 1.60 X 0.82 X 0.60 mm body 0603(1608-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0603" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-0805(2012-METRIC)" package="RESC2012X65">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378559/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 2.00 X 1.25 X 0.65 mm body 0805(2012-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0805" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1206(3216-METRIC)" package="RESC3216X70">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378566/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 3.20 X 1.60 X 0.70 mm body 1206(3216-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1206" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-1210(3225-METRIC)" package="RESC3224X71">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378563/8"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 3.20 X 2.49 X 0.71 mm body 1210(3225-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1210" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-2010(5025-METRIC)" package="RESC5025X71">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378564/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 5.00 X 2.50 X 0.71 mm body 2010(5025-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="2010" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="CHIP-2512(6332-METRIC)" package="RESC6332X71">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378557/8"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Chip Resistor 6.30 X 3.20 X 0.71 mm body 2512(6332-METRIC) Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="2512" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="AXIAL-11.7MM-PITCH" package="RESAD1176W63L850D250B">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378560/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Axial Resistor 11.76 mm pitch 8.5 mm body length 2.5 mm body diameter" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="Axial" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Through Hole" constant="no"/>
</technology>
</technologies>
</device>
<device name="MELF(3515-METRIC)" package="RESMELF3515">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378562/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="MELF Resistor 3.50 mm length Resistor 1.52 mm diameter 3515-METRIC Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="MELF" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="MELF(2014-METRIC)" package="RESMELF2014">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378558/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="MELF Resistor 2.00 mm length Resistor 1.40 mm diameter 2014-METRIC Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="MELF" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="MELF(5924-METRIC)" package="RESMELF5924">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378567/8"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="MELF Resistor 5.90 mm length Resistor 2.45 mm diameter 5924-METRIC Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="MELF" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="MELF(3218-METRIC)" package="RESMELF3218">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378556/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="MELF Resistor 3.20 mm length Resistor 1.80 mm diameter 3218-METRIC Package" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="MELF" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="AXIAL-7.2MM-PITCH" package="RESAD724W46L381D178B">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:16378561/7"/>
</package3dinstances>
<technologies>
<technology name="_">
<attribute name="CATEGORY" value="Resistors" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Axial Resistor 7.24 mm pitch 3.81 mm body length 1.78 mm body diameter" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="Axial" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="" constant="no"/>
<attribute name="TEMPERATURE_COEFFICIENT" value="" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TOLERANCE" value="" constant="no"/>
<attribute name="TYPE" value="" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Through Hole" constant="no"/>
</technology>
</technologies>
</device>
</devices>
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
</deviceset>
</devicesets>
</library>
<library name="LED" urn="urn:adsk.eagle:library:22900745">
<description>LED parts CHIP-Flat Top, Round Top</description>
<packages>
<package name="LEDC1608X35N_FLAT-R" urn="urn:adsk.eagle:footprint:24294736/2" library_version="27">
<description>Chip LED, 1.60 X 0.80 X 0.35 mm body
 &lt;p&gt;Chip LED package with body size 1.60 X 0.80 X 0.35 mm&lt;/p&gt;</description>
<smd name="C" x="-0.75" y="0" dx="0.6118" dy="0.9118" layer="1"/>
<smd name="A" x="0.75" y="0" dx="0.6118" dy="0.9118" layer="1"/>
<wire x1="-1.3099" y1="0.7699" x2="0.8" y2="0.7699" width="0.12" layer="21"/>
<wire x1="-1.3099" y1="0.7699" x2="-1.3099" y2="-0.7699" width="0.12" layer="21"/>
<wire x1="-1.3099" y1="-0.7699" x2="0.8" y2="-0.7699" width="0.12" layer="21"/>
<wire x1="-0.8" y1="-0.4" x2="-0.8" y2="0.4" width="0.12" layer="51"/>
<wire x1="-0.8" y1="0.4" x2="0.8" y2="0.4" width="0.12" layer="51"/>
<wire x1="0.8" y1="0.4" x2="0.8" y2="-0.4" width="0.12" layer="51"/>
<wire x1="0.8" y1="-0.4" x2="-0.8" y2="-0.4" width="0.12" layer="51"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="LEDC1608X55N_FLAT-R" urn="urn:adsk.eagle:footprint:24294737/2" library_version="27">
<description>Chip LED, 1.60 X 0.80 X 0.55 mm body
 &lt;p&gt;Chip LED package with body size 1.60 X 0.80 X 0.55 mm&lt;/p&gt;</description>
<smd name="C" x="-0.75" y="0" dx="0.6118" dy="0.9118" layer="1"/>
<smd name="A" x="0.75" y="0" dx="0.6118" dy="0.9118" layer="1"/>
<wire x1="-1.3099" y1="0.7699" x2="0.8" y2="0.7699" width="0.12" layer="21"/>
<wire x1="-1.3099" y1="0.7699" x2="-1.3099" y2="-0.7699" width="0.12" layer="21"/>
<wire x1="-1.3099" y1="-0.7699" x2="0.8" y2="-0.7699" width="0.12" layer="21"/>
<wire x1="-0.8" y1="-0.4" x2="-0.8" y2="0.4" width="0.12" layer="51"/>
<wire x1="-0.8" y1="0.4" x2="0.8" y2="0.4" width="0.12" layer="51"/>
<wire x1="0.8" y1="0.4" x2="0.8" y2="-0.4" width="0.12" layer="51"/>
<wire x1="0.8" y1="-0.4" x2="-0.8" y2="-0.4" width="0.12" layer="51"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="LEDC1608X80N_FLAT-R" urn="urn:adsk.eagle:footprint:24294739/2" library_version="27">
<description>Chip LED, 1.60 X 0.80 X 0.80 mm body
 &lt;p&gt;Chip LED package with body size 1.60 X 0.80 X 0.80 mm&lt;/p&gt;</description>
<smd name="C" x="-0.75" y="0" dx="0.6118" dy="0.9118" layer="1"/>
<smd name="A" x="0.75" y="0" dx="0.6118" dy="0.9118" layer="1"/>
<wire x1="-1.3099" y1="0.7699" x2="0.8" y2="0.7699" width="0.12" layer="21"/>
<wire x1="-1.3099" y1="0.7699" x2="-1.3099" y2="-0.7699" width="0.12" layer="21"/>
<wire x1="-1.3099" y1="-0.7699" x2="0.8" y2="-0.7699" width="0.12" layer="21"/>
<wire x1="-0.8" y1="-0.4" x2="-0.8" y2="0.4" width="0.12" layer="51"/>
<wire x1="-0.8" y1="0.4" x2="0.8" y2="0.4" width="0.12" layer="51"/>
<wire x1="0.8" y1="0.4" x2="0.8" y2="-0.4" width="0.12" layer="51"/>
<wire x1="0.8" y1="-0.4" x2="-0.8" y2="-0.4" width="0.12" layer="51"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="LEDC2012X110N_FLAT-R" urn="urn:adsk.eagle:footprint:24294742/2" library_version="27">
<description>Chip LED, 2.00 X 1.25 X 1.10 mm body
 &lt;p&gt;Chip LED package with body size 2.00 X 1.25 X 1.10 mm&lt;/p&gt;</description>
<smd name="C" x="-1.025" y="0" dx="0.7618" dy="1.3618" layer="1"/>
<smd name="A" x="1.025" y="0" dx="0.7618" dy="1.3618" layer="1"/>
<wire x1="-1.6599" y1="0.9949" x2="1" y2="0.9949" width="0.12" layer="21"/>
<wire x1="-1.6599" y1="0.9949" x2="-1.6599" y2="-0.9949" width="0.12" layer="21"/>
<wire x1="-1.6599" y1="-0.9949" x2="1" y2="-0.9949" width="0.12" layer="21"/>
<wire x1="-1" y1="-0.625" x2="-1" y2="0.625" width="0.12" layer="51"/>
<wire x1="-1" y1="0.625" x2="1" y2="0.625" width="0.12" layer="51"/>
<wire x1="1" y1="0.625" x2="1" y2="-0.625" width="0.12" layer="51"/>
<wire x1="1" y1="-0.625" x2="-1" y2="-0.625" width="0.12" layer="51"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
<package name="LEDC3216X75N_FLAT-R" urn="urn:adsk.eagle:footprint:24294744/3" library_version="27">
<description>Chip LED, 3.20 X 1.60 X 0.75 mm body
 &lt;p&gt;Chip LED package with body size 3.20 X 1.60 X 0.75 mm&lt;/p&gt;</description>
<smd name="C" x="-1.525" y="0" dx="0.9618" dy="1.7118" layer="1"/>
<smd name="A" x="1.525" y="0" dx="0.9618" dy="1.7118" layer="1"/>
<wire x1="-2.2599" y1="1.1699" x2="1.6" y2="1.1699" width="0.12" layer="21"/>
<wire x1="-2.2599" y1="1.1699" x2="-2.2599" y2="-1.1699" width="0.12" layer="21"/>
<wire x1="-2.2599" y1="-1.1699" x2="1.6" y2="-1.1699" width="0.12" layer="21"/>
<wire x1="-1.6" y1="-0.8" x2="-1.6" y2="0.8" width="0.12" layer="51"/>
<wire x1="-1.6" y1="0.8" x2="1.6" y2="0.8" width="0.12" layer="51"/>
<wire x1="1.6" y1="0.8" x2="1.6" y2="-0.8" width="0.12" layer="51"/>
<wire x1="1.6" y1="-0.8" x2="-1.6" y2="-0.8" width="0.12" layer="51"/>
<text x="0" y="2.54" size="1.27" layer="25" align="center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="center">&gt;VALUE</text>
</package>
<package name="LEDC1005X25N_FLAT-R" urn="urn:adsk.eagle:footprint:24294731/2" library_version="27">
<description>Chip LED, 1.00 X 0.50 X 0.25 mm body
 &lt;p&gt;Chip LED package with body size 1.00 X 0.50 X 0.25 mm&lt;/p&gt;</description>
<smd name="C" x="-0.45" y="0" dx="0.7" dy="0.5" layer="1"/>
<smd name="A" x="0.45" y="0" dx="0.7" dy="0.5" layer="1"/>
<wire x1="-1.0099" y1="0.6199" x2="0.5" y2="0.6199" width="0.12" layer="21"/>
<wire x1="-1.0099" y1="0.6199" x2="-1.0099" y2="-0.6199" width="0.12" layer="21"/>
<wire x1="-1.0099" y1="-0.6199" x2="0.5" y2="-0.6199" width="0.12" layer="21"/>
<wire x1="-0.5" y1="-0.25" x2="-0.5" y2="0.25" width="0.12" layer="51"/>
<wire x1="-0.5" y1="0.25" x2="0.5" y2="0.25" width="0.12" layer="51"/>
<wire x1="0.5" y1="0.25" x2="0.5" y2="-0.25" width="0.12" layer="51"/>
<wire x1="0.5" y1="-0.25" x2="-0.5" y2="-0.25" width="0.12" layer="51"/>
<text x="0" y="2.54" size="1.27" layer="25" align="top-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.27" layer="27" align="bottom-center">&gt;VALUE</text>
</package>
</packages>
<packages3d>
<package3d name="LEDC1608X35N_FLAT-R" urn="urn:adsk.eagle:package:24294797/3" type="model">
<description>Chip LED, 1.60 X 0.80 X 0.35 mm body
 &lt;p&gt;Chip LED package with body size 1.60 X 0.80 X 0.35 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="LEDC1608X35N_FLAT-R"/>
</packageinstances>
</package3d>
<package3d name="LEDC1608X55N_FLAT-R" urn="urn:adsk.eagle:package:24294799/3" type="model">
<description>Chip LED, 1.60 X 0.80 X 0.55 mm body
 &lt;p&gt;Chip LED package with body size 1.60 X 0.80 X 0.55 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="LEDC1608X55N_FLAT-R"/>
</packageinstances>
</package3d>
<package3d name="LEDC1608X80N_FLAT-R" urn="urn:adsk.eagle:package:24294802/3" type="model">
<description>Chip LED, 1.60 X 0.80 X 0.80 mm body
 &lt;p&gt;Chip LED package with body size 1.60 X 0.80 X 0.80 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="LEDC1608X80N_FLAT-R"/>
</packageinstances>
</package3d>
<package3d name="LEDC2012X110N_FLAT-R" urn="urn:adsk.eagle:package:24294806/3" type="model">
<description>Chip LED, 2.00 X 1.25 X 1.10 mm body
 &lt;p&gt;Chip LED package with body size 2.00 X 1.25 X 1.10 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="LEDC2012X110N_FLAT-R"/>
</packageinstances>
</package3d>
<package3d name="LEDC3216X75N_FLAT-R" urn="urn:adsk.eagle:package:24294810/4" type="model">
<description>Chip LED, 3.20 X 1.60 X 0.75 mm body
 &lt;p&gt;Chip LED package with body size 3.20 X 1.60 X 0.75 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="LEDC3216X75N_FLAT-R"/>
</packageinstances>
</package3d>
<package3d name="LEDC1005X25N_FLAT-R" urn="urn:adsk.eagle:package:24294790/3" type="model">
<description>Chip LED, 1.00 X 0.50 X 0.25 mm body
 &lt;p&gt;Chip LED package with body size 1.00 X 0.50 X 0.25 mm&lt;/p&gt;</description>
<packageinstances>
<packageinstance name="LEDC1005X25N_FLAT-R"/>
</packageinstances>
</package3d>
</packages3d>
<symbols>
<symbol name="LED" urn="urn:adsk.eagle:symbol:22900757/7" library_version="27">
<pin name="C" x="2.54" y="0" visible="off" length="point" direction="pas" rot="R180"/>
<pin name="A" x="-2.54" y="0" visible="off" length="point" direction="pas"/>
<wire x1="-1.27" y1="-1.27" x2="1.27" y2="0" width="0.1524" layer="94"/>
<wire x1="1.27" y1="0" x2="-1.27" y2="1.27" width="0.1524" layer="94"/>
<wire x1="-1.27" y1="1.27" x2="-1.27" y2="0" width="0.1524" layer="94"/>
<wire x1="-1.27" y1="0" x2="-1.27" y2="-1.27" width="0.1524" layer="94"/>
<wire x1="1.397" y1="1.27" x2="1.397" y2="-1.27" width="0.1524" layer="94"/>
<wire x1="2.54" y1="0" x2="1.27" y2="0" width="0.1524" layer="94"/>
<wire x1="-1.27" y1="0" x2="-2.54" y2="0" width="0.1524" layer="94"/>
<wire x1="1.143" y1="1.397" x2="1.143" y2="1.905" width="0.1524" layer="94"/>
<wire x1="1.143" y1="1.905" x2="0.635" y2="1.905" width="0.1524" layer="94"/>
<wire x1="1.143" y1="1.905" x2="0.4697125" y2="1.22660625" width="0.1524" layer="94"/>
<wire x1="0.381" y1="1.778" x2="0.381" y2="2.286" width="0.1524" layer="94"/>
<wire x1="0.381" y1="2.286" x2="-0.127" y2="2.286" width="0.1524" layer="94"/>
<wire x1="0.381" y1="2.286" x2="-0.2922875" y2="1.60760625" width="0.1524" layer="94"/>
<text x="0" y="2.54" size="1.778" layer="95" align="bottom-center">&gt;NAME</text>
<text x="0" y="-2.54" size="1.778" layer="96" align="center">&gt;VALUE</text>
</symbol>
</symbols>
<devicesets>
<deviceset name="CHIP-FLAT-R" urn="urn:adsk.eagle:component:22900849/11" prefix="D" library_version="27">
<description>Red LED - Generic</description>
<gates>
<gate name="G$1" symbol="LED" x="0" y="0"/>
</gates>
<devices>
<device name="_0603-0.35MM" package="LEDC1608X35N_FLAT-R">
<connects>
<connect gate="G$1" pin="A" pad="A"/>
<connect gate="G$1" pin="C" pad="C"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:24294797/3"/>
</package3dinstances>
<technologies>
<technology name="">
<attribute name="CATEGORY" value="LED" constant="no"/>
<attribute name="COLOR" value="Red" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Red LED Indication 0603 (1608 Metric)" constant="no"/>
<attribute name="FORWARD_CURRENT" value="" constant="no"/>
<attribute name="FORWARD_VOLTAGE" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0603" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="Chip LED" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="Square with Flat Top" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="_0603-0.55MM" package="LEDC1608X55N_FLAT-R">
<connects>
<connect gate="G$1" pin="A" pad="A"/>
<connect gate="G$1" pin="C" pad="C"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:24294799/3"/>
</package3dinstances>
<technologies>
<technology name="">
<attribute name="CATEGORY" value="LED" constant="no"/>
<attribute name="COLOR" value="Red" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Red LED Indication 0603 (1608 Metric)" constant="no"/>
<attribute name="FORWARD_CURRENT" value="" constant="no"/>
<attribute name="FORWARD_VOLTAGE" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0603" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="Chip LED" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="Square with Flat Top" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="_0603-0.80MM" package="LEDC1608X80N_FLAT-R">
<connects>
<connect gate="G$1" pin="A" pad="A"/>
<connect gate="G$1" pin="C" pad="C"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:24294802/3"/>
</package3dinstances>
<technologies>
<technology name="">
<attribute name="CATEGORY" value="LED" constant="no"/>
<attribute name="COLOR" value="Red" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Red LED Indication 0603 (1608 Metric)" constant="no"/>
<attribute name="FORWARD_CURRENT" value="" constant="no"/>
<attribute name="FORWARD_VOLTAGE" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0603" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="Chip LED" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="Square with Flat Top" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="_0805" package="LEDC2012X110N_FLAT-R">
<connects>
<connect gate="G$1" pin="A" pad="A"/>
<connect gate="G$1" pin="C" pad="C"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:24294806/3"/>
</package3dinstances>
<technologies>
<technology name="">
<attribute name="CATEGORY" value="LED" constant="no"/>
<attribute name="COLOR" value="Red" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Red LED Indication 0805 (2012 Metric)" constant="no"/>
<attribute name="FORWARD_CURRENT" value="" constant="no"/>
<attribute name="FORWARD_VOLTAGE" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0805" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="Chip LED" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="Square with Flat Top" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="_1206" package="LEDC3216X75N_FLAT-R">
<connects>
<connect gate="G$1" pin="A" pad="A"/>
<connect gate="G$1" pin="C" pad="C"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:24294810/4"/>
</package3dinstances>
<technologies>
<technology name="">
<attribute name="CATEGORY" value="LED" constant="no"/>
<attribute name="COLOR" value="Red" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Red LED Indication 1206 (3216 Metric)" constant="no"/>
<attribute name="FORWARD_CURRENT" value="" constant="no"/>
<attribute name="FORWARD_VOLTAGE" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="1206" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="Chip LED" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="Square with Flat Top" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
<device name="_0402" package="LEDC1005X25N_FLAT-R">
<connects>
<connect gate="G$1" pin="A" pad="A"/>
<connect gate="G$1" pin="C" pad="C"/>
</connects>
<package3dinstances>
<package3dinstance package3d_urn="urn:adsk.eagle:package:24294790/3"/>
</package3dinstances>
<technologies>
<technology name="">
<attribute name="CATEGORY" value="LED" constant="no"/>
<attribute name="COLOR" value="Red" constant="no"/>
<attribute name="DATASHEET" value="" constant="no"/>
<attribute name="DESCRIPTION" value="Red LED Indication 0402 (1005 Metric)" constant="no"/>
<attribute name="FORWARD_CURRENT" value="" constant="no"/>
<attribute name="FORWARD_VOLTAGE" value="" constant="no"/>
<attribute name="MANUFACTURER" value="" constant="no"/>
<attribute name="OPERATING_TEMPERATURE" value="" constant="no"/>
<attribute name="PACKAGE_SIZE" value="0402" constant="no"/>
<attribute name="PART_STATUS" value="" constant="no"/>
<attribute name="ROHS" value="" constant="no"/>
<attribute name="SERIES" value="" constant="no"/>
<attribute name="SUBCATEGORY" value="Chip LED" constant="no"/>
<attribute name="THERMALLOSS" value="" constant="no"/>
<attribute name="TYPE" value="Square with Flat Top" constant="no"/>
<attribute name="MPN" value="" constant="no"/>
<attribute name="PACKAGE_TYPE" value="Surface Mount" constant="no"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
</devicesets>
</library>
<library name="Ducky Library" urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ">
<packages>
<package name="QFN50P300X300X80-17N" library_version="2">
<rectangle x1="-0.35" y1="-0.35" x2="0.35" y2="0.35" layer="31"/>
<text x="-2.34" y="-3.105" size="1.27" layer="27" align="top-left">&gt;VALUE</text>
<text x="-2.34" y="3.105" size="1.27" layer="25">&gt;NAME</text>
<circle x="-2.475" y="0.75" radius="0.1" width="0.2" layer="21"/>
<circle x="-2.475" y="0.75" radius="0.1" width="0.2" layer="51"/>
<wire x1="1.5" y1="-1.5" x2="-1.5" y2="-1.5" width="0.127" layer="51"/>
<wire x1="1.5" y1="1.5" x2="-1.5" y2="1.5" width="0.127" layer="51"/>
<wire x1="1.5" y1="-1.5" x2="1.5" y2="1.5" width="0.127" layer="51"/>
<wire x1="-1.5" y1="-1.5" x2="-1.5" y2="1.5" width="0.127" layer="51"/>
<wire x1="1.5" y1="-1.5" x2="1.205" y2="-1.5" width="0.127" layer="21"/>
<wire x1="1.5" y1="1.5" x2="1.205" y2="1.5" width="0.127" layer="21"/>
<wire x1="-1.5" y1="-1.5" x2="-1.205" y2="-1.5" width="0.127" layer="21"/>
<wire x1="-1.5" y1="1.5" x2="-1.205" y2="1.5" width="0.127" layer="21"/>
<wire x1="1.5" y1="-1.5" x2="1.5" y2="-1.205" width="0.127" layer="21"/>
<wire x1="1.5" y1="1.5" x2="1.5" y2="1.205" width="0.127" layer="21"/>
<wire x1="-1.5" y1="-1.5" x2="-1.5" y2="-1.205" width="0.127" layer="21"/>
<wire x1="-1.5" y1="1.5" x2="-1.5" y2="1.205" width="0.127" layer="21"/>
<wire x1="-2.105" y1="-2.105" x2="2.105" y2="-2.105" width="0.05" layer="39"/>
<wire x1="-2.105" y1="2.105" x2="2.105" y2="2.105" width="0.05" layer="39"/>
<wire x1="-2.105" y1="-2.105" x2="-2.105" y2="2.105" width="0.05" layer="39"/>
<wire x1="2.105" y1="-2.105" x2="2.105" y2="2.105" width="0.05" layer="39"/>
<smd name="5" x="-0.75" y="-1.435" dx="0.27" dy="0.84" layer="1" roundness="25"/>
<smd name="6" x="-0.25" y="-1.435" dx="0.27" dy="0.84" layer="1" roundness="25"/>
<smd name="7" x="0.25" y="-1.435" dx="0.27" dy="0.84" layer="1" roundness="25"/>
<smd name="8" x="0.75" y="-1.435" dx="0.27" dy="0.84" layer="1" roundness="25"/>
<smd name="13" x="0.75" y="1.435" dx="0.27" dy="0.84" layer="1" roundness="25"/>
<smd name="14" x="0.25" y="1.435" dx="0.27" dy="0.84" layer="1" roundness="25"/>
<smd name="15" x="-0.25" y="1.435" dx="0.27" dy="0.84" layer="1" roundness="25"/>
<smd name="16" x="-0.75" y="1.435" dx="0.27" dy="0.84" layer="1" roundness="25"/>
<smd name="1" x="-1.435" y="0.75" dx="0.84" dy="0.27" layer="1" roundness="25"/>
<smd name="2" x="-1.435" y="0.25" dx="0.84" dy="0.27" layer="1" roundness="25"/>
<smd name="3" x="-1.435" y="-0.25" dx="0.84" dy="0.27" layer="1" roundness="25"/>
<smd name="4" x="-1.435" y="-0.75" dx="0.84" dy="0.27" layer="1" roundness="25"/>
<smd name="9" x="1.435" y="-0.75" dx="0.84" dy="0.27" layer="1" roundness="25"/>
<smd name="10" x="1.435" y="-0.25" dx="0.84" dy="0.27" layer="1" roundness="25"/>
<smd name="11" x="1.435" y="0.25" dx="0.84" dy="0.27" layer="1" roundness="25"/>
<smd name="12" x="1.435" y="0.75" dx="0.84" dy="0.27" layer="1" roundness="25"/>
<smd name="17" x="0" y="0" dx="1.1" dy="1.1" layer="1" cream="no"/>
</package>
<package name="CONN_SM02B-SRSS-TB_JST" library_version="12">
<smd name="1" x="0.5" y="-2.0985" dx="0.6604" dy="1.5494" layer="1"/>
<smd name="2" x="-0.5" y="-2.0985" dx="0.6604" dy="1.5494" layer="1"/>
<smd name="3" x="-1.8" y="1.7765" dx="1.2954" dy="1.905" layer="1"/>
<smd name="4" x="1.8" y="1.7765" dx="1.2954" dy="1.905" layer="1"/>
<wire x1="-0.5" y1="-2.0985" x2="-0.5" y2="5.269" width="0.1524" layer="48"/>
<wire x1="0.5" y1="-2.0985" x2="0.5" y2="5.269" width="0.1524" layer="48"/>
<wire x1="-0.5" y1="4.888" x2="-1.77" y2="4.888" width="0.1524" layer="48"/>
<wire x1="0.5" y1="4.888" x2="1.77" y2="4.888" width="0.1524" layer="48"/>
<wire x1="-0.5" y1="4.888" x2="-0.754" y2="5.015" width="0.1524" layer="48"/>
<wire x1="-0.5" y1="4.888" x2="-0.754" y2="4.761" width="0.1524" layer="48"/>
<wire x1="-0.754" y1="5.015" x2="-0.754" y2="4.761" width="0.1524" layer="48"/>
<wire x1="0.5" y1="4.888" x2="0.754" y2="5.015" width="0.1524" layer="48"/>
<wire x1="0.5" y1="4.888" x2="0.754" y2="4.761" width="0.1524" layer="48"/>
<wire x1="0.754" y1="5.015" x2="0.754" y2="4.761" width="0.1524" layer="48"/>
<wire x1="-1.8" y1="1.7765" x2="-1.8" y2="10.984" width="0.1524" layer="48"/>
<wire x1="1.8" y1="1.7765" x2="1.8" y2="10.984" width="0.1524" layer="48"/>
<wire x1="-1.8" y1="10.603" x2="-3.07" y2="10.603" width="0.1524" layer="48"/>
<wire x1="1.8" y1="10.603" x2="3.07" y2="10.603" width="0.1524" layer="48"/>
<wire x1="-1.8" y1="10.603" x2="-2.054" y2="10.73" width="0.1524" layer="48"/>
<wire x1="-1.8" y1="10.603" x2="-2.054" y2="10.476" width="0.1524" layer="48"/>
<wire x1="-2.054" y1="10.73" x2="-2.054" y2="10.476" width="0.1524" layer="48"/>
<wire x1="1.8" y1="10.603" x2="2.054" y2="10.73" width="0.1524" layer="48"/>
<wire x1="1.8" y1="10.603" x2="2.054" y2="10.476" width="0.1524" layer="48"/>
<wire x1="2.054" y1="10.73" x2="2.054" y2="10.476" width="0.1524" layer="48"/>
<wire x1="-1.9939" y1="2.4765" x2="-1.9939" y2="13.524" width="0.1524" layer="48"/>
<wire x1="1.9939" y1="2.4765" x2="1.9939" y2="13.524" width="0.1524" layer="48"/>
<wire x1="-1.9939" y1="13.143" x2="1.9939" y2="13.143" width="0.1524" layer="48"/>
<wire x1="-1.9939" y1="13.143" x2="-1.7399" y2="13.27" width="0.1524" layer="48"/>
<wire x1="-1.9939" y1="13.143" x2="-1.7399" y2="13.016" width="0.1524" layer="48"/>
<wire x1="-1.7399" y1="13.27" x2="-1.7399" y2="13.016" width="0.1524" layer="48"/>
<wire x1="1.9939" y1="13.143" x2="1.7399" y2="13.27" width="0.1524" layer="48"/>
<wire x1="1.9939" y1="13.143" x2="1.7399" y2="13.016" width="0.1524" layer="48"/>
<wire x1="1.7399" y1="13.27" x2="1.7399" y2="13.016" width="0.1524" layer="48"/>
<wire x1="0.5" y1="-2.0985" x2="4.9149" y2="-2.0985" width="0.1524" layer="48"/>
<wire x1="0.5" y1="-2.0985" x2="4.9149" y2="-2.0985" width="0.1524" layer="48"/>
<wire x1="4.5339" y1="-2.0985" x2="4.5339" y2="-0.8285" width="0.1524" layer="48"/>
<wire x1="4.5339" y1="-2.0985" x2="4.5339" y2="-3.3685" width="0.1524" layer="48"/>
<wire x1="4.5339" y1="-2.0985" x2="4.4069" y2="-1.8445" width="0.1524" layer="48"/>
<wire x1="4.5339" y1="-2.0985" x2="4.6609" y2="-1.8445" width="0.1524" layer="48"/>
<wire x1="4.4069" y1="-1.8445" x2="4.6609" y2="-1.8445" width="0.1524" layer="48"/>
<wire x1="4.5339" y1="-2.0985" x2="4.4069" y2="-2.3525" width="0.1524" layer="48"/>
<wire x1="4.5339" y1="-2.0985" x2="4.6609" y2="-2.3525" width="0.1524" layer="48"/>
<wire x1="4.4069" y1="-2.3525" x2="4.6609" y2="-2.3525" width="0.1524" layer="48"/>
<wire x1="1.8" y1="1.7765" x2="-4.9877" y2="1.7765" width="0.1524" layer="48"/>
<wire x1="0" y1="-2.0985" x2="-4.9877" y2="-2.0985" width="0.1524" layer="48"/>
<wire x1="-4.6067" y1="1.7765" x2="-4.6067" y2="-2.0985" width="0.1524" layer="48"/>
<wire x1="-4.6067" y1="1.7765" x2="-4.7337" y2="1.5225" width="0.1524" layer="48"/>
<wire x1="-4.6067" y1="1.7765" x2="-4.4797" y2="1.5225" width="0.1524" layer="48"/>
<wire x1="-4.7337" y1="1.5225" x2="-4.4797" y2="1.5225" width="0.1524" layer="48"/>
<wire x1="-4.6067" y1="-2.0985" x2="-4.7337" y2="-1.8445" width="0.1524" layer="48"/>
<wire x1="-4.6067" y1="-2.0985" x2="-4.4797" y2="-1.8445" width="0.1524" layer="48"/>
<wire x1="-4.7337" y1="-1.8445" x2="-4.4797" y2="-1.8445" width="0.1524" layer="48"/>
<wire x1="-1.9939" y1="2.4765" x2="-13.2427" y2="2.4765" width="0.1524" layer="48"/>
<wire x1="0" y1="-2.0985" x2="-13.2427" y2="-2.0985" width="0.1524" layer="48"/>
<wire x1="-12.8617" y1="2.4765" x2="-12.8617" y2="-2.0985" width="0.1524" layer="48"/>
<wire x1="-12.8617" y1="2.4765" x2="-12.9887" y2="2.2225" width="0.1524" layer="48"/>
<wire x1="-12.8617" y1="2.4765" x2="-12.7347" y2="2.2225" width="0.1524" layer="48"/>
<wire x1="-12.9887" y1="2.2225" x2="-12.7347" y2="2.2225" width="0.1524" layer="48"/>
<wire x1="-12.8617" y1="-2.0985" x2="-12.9887" y2="-1.8445" width="0.1524" layer="48"/>
<wire x1="-12.8617" y1="-2.0985" x2="-12.7347" y2="-1.8445" width="0.1524" layer="48"/>
<wire x1="-12.9887" y1="-1.8445" x2="-12.7347" y2="-1.8445" width="0.1524" layer="48"/>
<wire x1="-1.9939" y1="2.4765" x2="-11.9727" y2="2.4765" width="0.1524" layer="48"/>
<wire x1="-1.9939" y1="-2.4765" x2="-11.9727" y2="-2.4765" width="0.1524" layer="48"/>
<wire x1="-11.5917" y1="2.4765" x2="-11.5917" y2="-2.4765" width="0.1524" layer="48"/>
<wire x1="-11.5917" y1="2.4765" x2="-11.7187" y2="2.2225" width="0.1524" layer="48"/>
<wire x1="-11.5917" y1="2.4765" x2="-11.4647" y2="2.2225" width="0.1524" layer="48"/>
<wire x1="-11.7187" y1="2.2225" x2="-11.4647" y2="2.2225" width="0.1524" layer="48"/>
<wire x1="-11.5917" y1="-2.4765" x2="-11.7187" y2="-2.2225" width="0.1524" layer="48"/>
<wire x1="-11.5917" y1="-2.4765" x2="-11.4647" y2="-2.2225" width="0.1524" layer="48"/>
<wire x1="-11.7187" y1="-2.2225" x2="-11.4647" y2="-2.2225" width="0.1524" layer="48"/>
<text x="-15.2035" y="-6.9372" size="1.27" layer="48" ratio="6">Default Padstyle: RX26Y61D0T</text>
<text x="-15.3899" y="-8.8422" size="1.27" layer="48" ratio="6">1st Mtg Padstyle: RX51Y75D0T</text>
<text x="-16.1525" y="-10.7472" size="1.27" layer="48" ratio="6">2nd Mtg Padstyle: EX70Y70D70P</text>
<text x="-16.1525" y="-12.6522" size="1.27" layer="48" ratio="6">3rd Mtg Padstyle: EX70Y70D70P</text>
<text x="-16.356" y="-14.5572" size="1.27" layer="48" ratio="6">Left Mtg Padstyle: EX60Y60D30P</text>
<text x="-16.9323" y="-16.4622" size="1.27" layer="48" ratio="6">Right Mtg Padstyle: EX60Y60D30P</text>
<text x="-14.8136" y="-18.3672" size="1.27" layer="48" ratio="6">Alt Padstyle 1: OX60Y90D30P</text>
<text x="-14.8136" y="-20.2722" size="1.27" layer="48" ratio="6">Alt Padstyle 2: OX90Y60D30P</text>
<text x="-2.2331" y="5.396" size="0.635" layer="48" ratio="4">0.039in/1mm</text>
<text x="-3.4661" y="11.111" size="0.635" layer="48" ratio="4">0.142in/3.6mm</text>
<text x="-4.0424" y="13.651" size="0.635" layer="48" ratio="4">0.157in/3.988mm</text>
<text x="5.0419" y="-2.416" size="0.635" layer="48" ratio="4">0in/0mm</text>
<text x="-13.1995" y="-0.4785" size="0.635" layer="48" ratio="4">0.153in/3.875mm</text>
<text x="-20.8783" y="-0.1285" size="0.635" layer="48" ratio="4">0.18in/4.575mm</text>
<text x="-20.1845" y="-0.3175" size="0.635" layer="48" ratio="4">0.195in/4.953mm</text>
<wire x1="-2.1209" y1="-2.6035" x2="-1.1629" y2="-2.6035" width="0.1524" layer="21"/>
<wire x1="2.1209" y1="-2.6035" x2="2.1209" y2="0.4913" width="0.1524" layer="21"/>
<wire x1="0.8196" y1="2.6035" x2="-0.8196" y2="2.6035" width="0.1524" layer="21"/>
<wire x1="-2.1209" y1="0.4913" x2="-2.1209" y2="-2.6035" width="0.1524" layer="21"/>
<wire x1="1.1629" y1="-2.6035" x2="2.1209" y2="-2.6035" width="0.1524" layer="21"/>
<wire x1="3.1369" y1="-2.0985" x2="2.3749" y2="-2.0985" width="0.508" layer="21" curve="-180"/>
<wire x1="2.3749" y1="-2.0985" x2="3.1369" y2="-2.0985" width="0.508" layer="21" curve="-180"/>
<wire x1="-1.9939" y1="-2.4765" x2="1.9939" y2="-2.4765" width="0.1524" layer="51"/>
<wire x1="1.9939" y1="-2.4765" x2="1.9939" y2="2.4765" width="0.1524" layer="51"/>
<wire x1="1.9939" y1="2.4765" x2="-1.9939" y2="2.4765" width="0.1524" layer="51"/>
<wire x1="-1.9939" y1="2.4765" x2="-1.9939" y2="-2.4765" width="0.1524" layer="51"/>
<wire x1="0.881" y1="-4.0035" x2="0.119" y2="-4.0035" width="0.508" layer="51" curve="-180"/>
<wire x1="0.119" y1="-4.0035" x2="0.881" y2="-4.0035" width="0.508" layer="51" curve="-180"/>
<wire x1="3.1369" y1="-2.0985" x2="2.3749" y2="-2.0985" width="0.508" layer="22" curve="-180"/>
<wire x1="2.3749" y1="-2.0985" x2="3.1369" y2="-2.0985" width="0.508" layer="22" curve="-180"/>
<text x="-3.2712" y="-2.7335" size="1.27" layer="27" ratio="6">&gt;Name</text>
<text x="-1.7288" y="-2.7335" size="1.27" layer="27" ratio="6">&gt;Value</text>
</package>
<package name="SW_KMR221GLFS" library_version="14">
<wire x1="-2.1" y1="1.4" x2="2.1" y2="1.4" width="0.127" layer="51"/>
<wire x1="2.1" y1="1.4" x2="2.1" y2="-1.4" width="0.127" layer="51"/>
<wire x1="2.1" y1="-1.4" x2="-2.1" y2="-1.4" width="0.127" layer="51"/>
<wire x1="-2.1" y1="-1.4" x2="-2.1" y2="1.4" width="0.127" layer="51"/>
<wire x1="-1.2" y1="-1.4" x2="1.2" y2="-1.4" width="0.2" layer="21"/>
<wire x1="-2.75" y1="1.95" x2="2.75" y2="1.95" width="0.05" layer="39"/>
<wire x1="2.75" y1="1.95" x2="2.75" y2="-1.65" width="0.05" layer="39"/>
<wire x1="2.75" y1="-1.65" x2="-2.75" y2="-1.65" width="0.05" layer="39"/>
<wire x1="-2.75" y1="-1.65" x2="-2.75" y2="1.95" width="0.05" layer="39"/>
<text x="-2.2525" y="2.05228125" size="1.271409375" layer="25">&gt;NAME</text>
<text x="-2.702840625" y="-3.153309375" size="1.271340625" layer="27">&gt;VALUE</text>
<smd name="1" x="-2.05" y="0.8" dx="0.9" dy="1" layer="1"/>
<smd name="2" x="-2.05" y="-0.8" dx="0.9" dy="1" layer="1"/>
<smd name="3" x="2.05" y="-0.8" dx="0.9" dy="1" layer="1"/>
<smd name="4" x="2.05" y="0.8" dx="0.9" dy="1" layer="1"/>
<smd name="5" x="0" y="1.425" dx="1.7" dy="0.55" layer="1"/>
</package>
<package name="LED_XL-5050RGBC-WS2812B" library_version="19">
<text x="-2.5" y="3" size="1.27" layer="25">&gt;NAME</text>
<text x="-2.5" y="-4.25" size="1.27" layer="27">&gt;VALUE</text>
<wire x1="-2.5" y1="2.5" x2="2.5" y2="2.5" width="0.127" layer="51"/>
<wire x1="2.5" y1="2.5" x2="2.5" y2="-2.5" width="0.127" layer="51"/>
<wire x1="2.5" y1="-2.5" x2="-2.5" y2="-2.5" width="0.127" layer="51"/>
<wire x1="-2.5" y1="-2.5" x2="-2.5" y2="2.5" width="0.127" layer="51"/>
<wire x1="-3.45" y1="2.75" x2="3.45" y2="2.75" width="0.05" layer="39"/>
<wire x1="3.45" y1="2.75" x2="3.45" y2="-2.75" width="0.05" layer="39"/>
<wire x1="3.45" y1="-2.75" x2="-3.45" y2="-2.75" width="0.05" layer="39"/>
<wire x1="-3.45" y1="-2.75" x2="-3.45" y2="2.75" width="0.05" layer="39"/>
<wire x1="-1.38" y1="2.5" x2="1.38" y2="2.5" width="0.127" layer="21"/>
<wire x1="-2.5" y1="-0.68" x2="-2.5" y2="0.68" width="0.127" layer="21"/>
<wire x1="1.38" y1="-2.5" x2="-1.38" y2="-2.5" width="0.127" layer="21"/>
<wire x1="2.5" y1="0.68" x2="2.5" y2="-0.68" width="0.127" layer="21"/>
<circle x="3.75" y="-2.25" radius="0.1" width="0.2" layer="21"/>
<circle x="3.75" y="-2.25" radius="0.1" width="0.2" layer="51"/>
<smd name="1" x="-2.45" y="1.75" dx="1.5" dy="1.5" layer="1"/>
<smd name="2" x="-2.45" y="-1.75" dx="1.5" dy="1.5" layer="1"/>
<smd name="3" x="2.45" y="-1.75" dx="1.5" dy="1.5" layer="1"/>
<smd name="4" x="2.45" y="1.75" dx="1.5" dy="1.5" layer="1"/>
</package>
<package name="CAP_UWF_6P3X5P4_NCH" library_version="21">
<smd name="1" x="-2.7051" y="0" dx="2.9972" dy="1.2192" layer="1"/>
<smd name="2" x="2.7051" y="0" dx="2.9972" dy="1.2192" layer="1"/>
<wire x1="4.4577" y1="0.4064" x2="7.1247" y2="0.4064" width="0.1524" layer="48"/>
<wire x1="4.4577" y1="-0.4064" x2="7.1247" y2="-0.4064" width="0.1524" layer="48"/>
<wire x1="6.7437" y1="0.4064" x2="6.7437" y2="1.6764" width="0.1524" layer="48"/>
<wire x1="6.7437" y1="-0.4064" x2="6.7437" y2="-1.6764" width="0.1524" layer="48"/>
<wire x1="6.7437" y1="0.4064" x2="6.6167" y2="0.6604" width="0.1524" layer="48"/>
<wire x1="6.7437" y1="0.4064" x2="6.8707" y2="0.6604" width="0.1524" layer="48"/>
<wire x1="6.6167" y1="0.6604" x2="6.8707" y2="0.6604" width="0.1524" layer="48"/>
<wire x1="6.7437" y1="-0.4064" x2="6.6167" y2="-0.6604" width="0.1524" layer="48"/>
<wire x1="6.7437" y1="-0.4064" x2="6.8707" y2="-0.6604" width="0.1524" layer="48"/>
<wire x1="6.6167" y1="-0.6604" x2="6.8707" y2="-0.6604" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="0.8636" x2="-3.6957" y2="6.223" width="0.1524" layer="48"/>
<wire x1="3.6957" y1="0.8636" x2="3.6957" y2="6.223" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="5.842" x2="3.6957" y2="5.842" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="5.842" x2="-3.4417" y2="5.969" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="5.842" x2="-3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="-3.4417" y1="5.969" x2="-3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="3.6957" y1="5.842" x2="3.4417" y2="5.969" width="0.1524" layer="48"/>
<wire x1="3.6957" y1="5.842" x2="3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="3.4417" y1="5.969" x2="3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="3.302" x2="-6.223" y2="3.302" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-3.302" x2="-6.223" y2="-3.302" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="3.302" x2="-5.842" y2="-3.302" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="3.302" x2="-5.969" y2="3.048" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="3.302" x2="-5.715" y2="3.048" width="0.1524" layer="48"/>
<wire x1="-5.969" y1="3.048" x2="-5.715" y2="3.048" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="-3.302" x2="-5.969" y2="-3.048" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="-3.302" x2="-5.715" y2="-3.048" width="0.1524" layer="48"/>
<wire x1="-5.969" y1="-3.048" x2="-5.715" y2="-3.048" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-0.8636" x2="-3.6957" y2="-6.223" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-0.3556" x2="-1.1049" y2="-6.223" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-5.842" x2="-4.9657" y2="-5.842" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-5.842" x2="0.1651" y2="-5.842" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-5.842" x2="-3.9497" y2="-5.715" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-5.842" x2="-3.9497" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-3.9497" y1="-5.715" x2="-3.9497" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-5.842" x2="-0.8509" y2="-5.715" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-5.842" x2="-0.8509" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-0.8509" y1="-5.715" x2="-0.8509" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-3.302" x2="-3.302" y2="-8.763" width="0.1524" layer="48"/>
<wire x1="3.302" y1="-3.302" x2="3.302" y2="-8.763" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-8.382" x2="3.302" y2="-8.382" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-8.382" x2="-3.048" y2="-8.255" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-8.382" x2="-3.048" y2="-8.509" width="0.1524" layer="48"/>
<wire x1="-3.048" y1="-8.255" x2="-3.048" y2="-8.509" width="0.1524" layer="48"/>
<wire x1="3.302" y1="-8.382" x2="3.048" y2="-8.255" width="0.1524" layer="48"/>
<wire x1="3.302" y1="-8.382" x2="3.048" y2="-8.509" width="0.1524" layer="48"/>
<wire x1="3.048" y1="-8.255" x2="3.048" y2="-8.509" width="0.1524" layer="48"/>
<text x="-15.7797" y="-11.4554" size="1.27" layer="48" ratio="6">Default Padstyle: RX118Y48D0T</text>
<text x="-18.0848" y="-13.9954" size="1.27" layer="48" ratio="6">Alternate 1 Padstyle: OX60Y90D30P</text>
<text x="-18.0848" y="-16.5354" size="1.27" layer="48" ratio="6">Alternate 2 Padstyle: OX90Y60D30P</text>
<text x="7.2517" y="-0.3175" size="0.635" layer="48" ratio="4">0.032in/0.813mm</text>
<text x="-4.0424" y="6.35" size="0.635" layer="48" ratio="4">0.291in/7.391mm</text>
<text x="-13.8586" y="-0.3175" size="0.635" layer="48" ratio="4">0.26in/6.604mm</text>
<text x="-6.4427" y="-6.985" size="0.635" layer="48" ratio="4">0.102in/2.591mm</text>
<text x="-3.7543" y="-9.525" size="0.635" layer="48" ratio="4">0.26in/6.604mm</text>
<wire x1="-3.429" y1="-3.429" x2="3.429" y2="-3.429" width="0.1524" layer="21"/>
<wire x1="3.429" y1="-3.429" x2="3.429" y2="-0.9423" width="0.1524" layer="21"/>
<wire x1="3.429" y1="3.429" x2="-3.429" y2="3.429" width="0.1524" layer="21"/>
<wire x1="-3.429" y1="3.429" x2="-3.429" y2="0.9423" width="0.1524" layer="21"/>
<wire x1="-3.429" y1="-0.9423" x2="-3.429" y2="-3.429" width="0.1524" layer="21"/>
<wire x1="3.429" y1="0.9423" x2="3.429" y2="3.429" width="0.1524" layer="21"/>
<wire x1="-3.302" y1="1.651" x2="-1.651" y2="3.302" width="0.1524" layer="51"/>
<wire x1="-3.302" y1="-1.651" x2="-1.651" y2="-3.302" width="0.1524" layer="51"/>
<wire x1="-3.302" y1="-3.302" x2="3.302" y2="-3.302" width="0.1524" layer="51"/>
<wire x1="3.302" y1="-3.302" x2="3.302" y2="3.302" width="0.1524" layer="51"/>
<wire x1="3.302" y1="3.302" x2="-3.302" y2="3.302" width="0.1524" layer="51"/>
<wire x1="-3.302" y1="3.302" x2="-3.302" y2="-3.302" width="0.1524" layer="51"/>
<polygon width="0.0254" layer="41" pour="solid">
<vertex x="-1.1557" y="-0.6604"/>
<vertex x="1.1557" y="-0.6604"/>
<vertex x="1.1557" y="0.6604"/>
<vertex x="-1.1557" y="0.6604"/>
</polygon>
<polygon width="0.0254" layer="41" pour="solid">
<vertex x="-3.2512" y="0.6604"/>
<vertex x="3.2512" y="0.6604"/>
<vertex x="3.2512" y="3.2512"/>
<vertex x="-3.2512" y="3.2512"/>
</polygon>
<polygon width="0.0254" layer="41" pour="solid">
<vertex x="-3.2512" y="-3.2512"/>
<vertex x="3.2512" y="-3.2512"/>
<vertex x="3.2512" y="-0.6604"/>
<vertex x="-3.2512" y="-0.6604"/>
</polygon>
<polygon width="0.0254" layer="41" pour="solid">
<vertex x="-1.1557" y="-0.6604"/>
<vertex x="1.1557" y="-0.6604"/>
<vertex x="1.1557" y="0.6604"/>
<vertex x="-1.1557" y="0.6604"/>
</polygon>
<text x="-3.2712" y="-0.635" size="1.27" layer="27" ratio="6">&gt;Name</text>
<text x="-1.7288" y="-0.635" size="1.27" layer="27" ratio="6">&gt;Value</text>
</package>
<package name="CAP_UWF_6P3X5P4_NCH-M" library_version="20">
<smd name="1" x="-2.7559" y="0" dx="3.302" dy="1.3208" layer="1"/>
<smd name="2" x="2.7559" y="0" dx="3.302" dy="1.3208" layer="1"/>
<wire x1="4.6609" y1="0.4064" x2="7.3279" y2="0.4064" width="0.1524" layer="48"/>
<wire x1="4.6609" y1="-0.4064" x2="7.3279" y2="-0.4064" width="0.1524" layer="48"/>
<wire x1="6.9469" y1="0.4064" x2="6.9469" y2="1.6764" width="0.1524" layer="48"/>
<wire x1="6.9469" y1="-0.4064" x2="6.9469" y2="-1.6764" width="0.1524" layer="48"/>
<wire x1="6.9469" y1="0.4064" x2="6.8199" y2="0.6604" width="0.1524" layer="48"/>
<wire x1="6.9469" y1="0.4064" x2="7.0739" y2="0.6604" width="0.1524" layer="48"/>
<wire x1="6.8199" y1="0.6604" x2="7.0739" y2="0.6604" width="0.1524" layer="48"/>
<wire x1="6.9469" y1="-0.4064" x2="6.8199" y2="-0.6604" width="0.1524" layer="48"/>
<wire x1="6.9469" y1="-0.4064" x2="7.0739" y2="-0.6604" width="0.1524" layer="48"/>
<wire x1="6.8199" y1="-0.6604" x2="7.0739" y2="-0.6604" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="0.9144" x2="-3.6957" y2="6.223" width="0.1524" layer="48"/>
<wire x1="3.6957" y1="0.9144" x2="3.6957" y2="6.223" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="5.842" x2="3.6957" y2="5.842" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="5.842" x2="-3.4417" y2="5.969" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="5.842" x2="-3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="-3.4417" y1="5.969" x2="-3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="3.6957" y1="5.842" x2="3.4417" y2="5.969" width="0.1524" layer="48"/>
<wire x1="3.6957" y1="5.842" x2="3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="3.4417" y1="5.969" x2="3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="3.302" x2="-6.223" y2="3.302" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-3.302" x2="-6.223" y2="-3.302" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="3.302" x2="-5.842" y2="-3.302" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="3.302" x2="-5.969" y2="3.048" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="3.302" x2="-5.715" y2="3.048" width="0.1524" layer="48"/>
<wire x1="-5.969" y1="3.048" x2="-5.715" y2="3.048" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="-3.302" x2="-5.969" y2="-3.048" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="-3.302" x2="-5.715" y2="-3.048" width="0.1524" layer="48"/>
<wire x1="-5.969" y1="-3.048" x2="-5.715" y2="-3.048" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-0.9144" x2="-3.6957" y2="-6.223" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-0.4064" x2="-1.1049" y2="-6.223" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-5.842" x2="-4.9657" y2="-5.842" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-5.842" x2="0.1651" y2="-5.842" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-5.842" x2="-3.9497" y2="-5.715" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-5.842" x2="-3.9497" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-3.9497" y1="-5.715" x2="-3.9497" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-5.842" x2="-0.8509" y2="-5.715" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-5.842" x2="-0.8509" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-0.8509" y1="-5.715" x2="-0.8509" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-3.302" x2="-3.302" y2="-8.763" width="0.1524" layer="48"/>
<wire x1="3.302" y1="-3.302" x2="3.302" y2="-8.763" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-8.382" x2="3.302" y2="-8.382" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-8.382" x2="-3.048" y2="-8.255" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-8.382" x2="-3.048" y2="-8.509" width="0.1524" layer="48"/>
<wire x1="-3.048" y1="-8.255" x2="-3.048" y2="-8.509" width="0.1524" layer="48"/>
<wire x1="3.302" y1="-8.382" x2="3.048" y2="-8.255" width="0.1524" layer="48"/>
<wire x1="3.302" y1="-8.382" x2="3.048" y2="-8.509" width="0.1524" layer="48"/>
<wire x1="3.048" y1="-8.255" x2="3.048" y2="-8.509" width="0.1524" layer="48"/>
<text x="-15.7797" y="-11.4046" size="1.27" layer="48" ratio="6">Default Padstyle: RX130Y52D0T</text>
<text x="-18.0848" y="-13.9446" size="1.27" layer="48" ratio="6">Alternate 1 Padstyle: OX60Y90D30P</text>
<text x="-18.0848" y="-16.4846" size="1.27" layer="48" ratio="6">Alternate 2 Padstyle: OX90Y60D30P</text>
<text x="7.4549" y="-0.3175" size="0.635" layer="48" ratio="4">0.032in/0.813mm</text>
<text x="-4.0424" y="6.35" size="0.635" layer="48" ratio="4">0.291in/7.391mm</text>
<text x="-13.8586" y="-0.3175" size="0.635" layer="48" ratio="4">0.26in/6.604mm</text>
<text x="-6.4427" y="-6.985" size="0.635" layer="48" ratio="4">0.102in/2.591mm</text>
<text x="-3.7543" y="-9.525" size="0.635" layer="48" ratio="4">0.26in/6.604mm</text>
<wire x1="-3.429" y1="-3.429" x2="3.429" y2="-3.429" width="0.1524" layer="21"/>
<wire x1="3.429" y1="-3.429" x2="3.429" y2="-0.9931" width="0.1524" layer="21"/>
<wire x1="3.429" y1="3.429" x2="-3.429" y2="3.429" width="0.1524" layer="21"/>
<wire x1="-3.429" y1="3.429" x2="-3.429" y2="0.9931" width="0.1524" layer="21"/>
<wire x1="-3.429" y1="-0.9931" x2="-3.429" y2="-3.429" width="0.1524" layer="21"/>
<wire x1="3.429" y1="0.9931" x2="3.429" y2="3.429" width="0.1524" layer="21"/>
<wire x1="-5.0927" y1="0" x2="-5.2451" y2="0" width="0.1524" layer="21" curve="-180"/>
<wire x1="-5.2451" y1="0" x2="-5.0927" y2="0" width="0.1524" layer="21" curve="-180"/>
<wire x1="-3.302" y1="1.651" x2="-1.651" y2="3.302" width="0.1524" layer="51"/>
<wire x1="-3.302" y1="-1.651" x2="-1.651" y2="-3.302" width="0.1524" layer="51"/>
<wire x1="-3.302" y1="-3.302" x2="3.302" y2="-3.302" width="0.1524" layer="51"/>
<wire x1="3.302" y1="-3.302" x2="3.302" y2="3.302" width="0.1524" layer="51"/>
<wire x1="3.302" y1="3.302" x2="-3.302" y2="3.302" width="0.1524" layer="51"/>
<wire x1="-3.302" y1="3.302" x2="-3.302" y2="-3.302" width="0.1524" layer="51"/>
<wire x1="-2.7178" y1="0" x2="-2.8702" y2="0" width="0" layer="51" curve="-180"/>
<wire x1="-2.8702" y1="0" x2="-2.7178" y2="0" width="0" layer="51" curve="-180"/>
<polygon width="0.1524" layer="41" pour="solid">
<vertex x="-1.0541" y="-0.7112"/>
<vertex x="1.0541" y="-0.7112"/>
<vertex x="1.0541" y="0.7112"/>
<vertex x="-1.0541" y="0.7112"/>
</polygon>
<polygon width="0.1524" layer="41" pour="solid">
<vertex x="-3.2512" y="0.7112"/>
<vertex x="3.2512" y="0.7112"/>
<vertex x="3.2512" y="3.2512"/>
<vertex x="-3.2512" y="3.2512"/>
</polygon>
<polygon width="0.1524" layer="41" pour="solid">
<vertex x="-3.2512" y="-3.2512"/>
<vertex x="3.2512" y="-3.2512"/>
<vertex x="3.2512" y="-0.7112"/>
<vertex x="-3.2512" y="-0.7112"/>
</polygon>
<polygon width="0.1524" layer="41" pour="solid">
<vertex x="-1.0541" y="-0.7112"/>
<vertex x="1.0541" y="-0.7112"/>
<vertex x="1.0541" y="0.7112"/>
<vertex x="-1.0541" y="0.7112"/>
</polygon>
<text x="-3.2712" y="-0.635" size="1.27" layer="27" ratio="6">&gt;Name</text>
<text x="-1.7288" y="-0.635" size="1.27" layer="27" ratio="6">&gt;Value</text>
</package>
<package name="CAP_UWF_6P3X5P4_NCH-L" library_version="20">
<smd name="1" x="-2.6543" y="0" dx="2.6924" dy="1.1176" layer="1"/>
<smd name="2" x="2.6543" y="0" dx="2.6924" dy="1.1176" layer="1"/>
<wire x1="4.2545" y1="0.4064" x2="6.9215" y2="0.4064" width="0.1524" layer="48"/>
<wire x1="4.2545" y1="-0.4064" x2="6.9215" y2="-0.4064" width="0.1524" layer="48"/>
<wire x1="6.5405" y1="0.4064" x2="6.5405" y2="1.6764" width="0.1524" layer="48"/>
<wire x1="6.5405" y1="-0.4064" x2="6.5405" y2="-1.6764" width="0.1524" layer="48"/>
<wire x1="6.5405" y1="0.4064" x2="6.4135" y2="0.6604" width="0.1524" layer="48"/>
<wire x1="6.5405" y1="0.4064" x2="6.6675" y2="0.6604" width="0.1524" layer="48"/>
<wire x1="6.4135" y1="0.6604" x2="6.6675" y2="0.6604" width="0.1524" layer="48"/>
<wire x1="6.5405" y1="-0.4064" x2="6.4135" y2="-0.6604" width="0.1524" layer="48"/>
<wire x1="6.5405" y1="-0.4064" x2="6.6675" y2="-0.6604" width="0.1524" layer="48"/>
<wire x1="6.4135" y1="-0.6604" x2="6.6675" y2="-0.6604" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="0.8128" x2="-3.6957" y2="6.223" width="0.1524" layer="48"/>
<wire x1="3.6957" y1="0.8128" x2="3.6957" y2="6.223" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="5.842" x2="3.6957" y2="5.842" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="5.842" x2="-3.4417" y2="5.969" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="5.842" x2="-3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="-3.4417" y1="5.969" x2="-3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="3.6957" y1="5.842" x2="3.4417" y2="5.969" width="0.1524" layer="48"/>
<wire x1="3.6957" y1="5.842" x2="3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="3.4417" y1="5.969" x2="3.4417" y2="5.715" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="3.302" x2="-6.223" y2="3.302" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-3.302" x2="-6.223" y2="-3.302" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="3.302" x2="-5.842" y2="-3.302" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="3.302" x2="-5.969" y2="3.048" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="3.302" x2="-5.715" y2="3.048" width="0.1524" layer="48"/>
<wire x1="-5.969" y1="3.048" x2="-5.715" y2="3.048" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="-3.302" x2="-5.969" y2="-3.048" width="0.1524" layer="48"/>
<wire x1="-5.842" y1="-3.302" x2="-5.715" y2="-3.048" width="0.1524" layer="48"/>
<wire x1="-5.969" y1="-3.048" x2="-5.715" y2="-3.048" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-0.8128" x2="-3.6957" y2="-6.223" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-0.3048" x2="-1.1049" y2="-6.223" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-5.842" x2="-4.9657" y2="-5.842" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-5.842" x2="0.1651" y2="-5.842" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-5.842" x2="-3.9497" y2="-5.715" width="0.1524" layer="48"/>
<wire x1="-3.6957" y1="-5.842" x2="-3.9497" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-3.9497" y1="-5.715" x2="-3.9497" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-5.842" x2="-0.8509" y2="-5.715" width="0.1524" layer="48"/>
<wire x1="-1.1049" y1="-5.842" x2="-0.8509" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-0.8509" y1="-5.715" x2="-0.8509" y2="-5.969" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-3.302" x2="-3.302" y2="-8.763" width="0.1524" layer="48"/>
<wire x1="3.302" y1="-3.302" x2="3.302" y2="-8.763" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-8.382" x2="3.302" y2="-8.382" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-8.382" x2="-3.048" y2="-8.255" width="0.1524" layer="48"/>
<wire x1="-3.302" y1="-8.382" x2="-3.048" y2="-8.509" width="0.1524" layer="48"/>
<wire x1="-3.048" y1="-8.255" x2="-3.048" y2="-8.509" width="0.1524" layer="48"/>
<wire x1="3.302" y1="-8.382" x2="3.048" y2="-8.255" width="0.1524" layer="48"/>
<wire x1="3.302" y1="-8.382" x2="3.048" y2="-8.509" width="0.1524" layer="48"/>
<wire x1="3.048" y1="-8.255" x2="3.048" y2="-8.509" width="0.1524" layer="48"/>
<text x="-15.7797" y="-11.5062" size="1.27" layer="48" ratio="6">Default Padstyle: RX106Y44D0T</text>
<text x="-18.0848" y="-14.0462" size="1.27" layer="48" ratio="6">Alternate 1 Padstyle: OX60Y90D30P</text>
<text x="-18.0848" y="-16.5862" size="1.27" layer="48" ratio="6">Alternate 2 Padstyle: OX90Y60D30P</text>
<text x="7.0485" y="-0.3175" size="0.635" layer="48" ratio="4">0.032in/0.813mm</text>
<text x="-4.0424" y="6.35" size="0.635" layer="48" ratio="4">0.291in/7.391mm</text>
<text x="-13.8586" y="-0.3175" size="0.635" layer="48" ratio="4">0.26in/6.604mm</text>
<text x="-6.4427" y="-6.985" size="0.635" layer="48" ratio="4">0.102in/2.591mm</text>
<text x="-3.7543" y="-9.525" size="0.635" layer="48" ratio="4">0.26in/6.604mm</text>
<wire x1="-3.429" y1="-3.429" x2="3.429" y2="-3.429" width="0.1524" layer="21"/>
<wire x1="3.429" y1="-3.429" x2="3.429" y2="-0.8915" width="0.1524" layer="21"/>
<wire x1="3.429" y1="3.429" x2="-3.429" y2="3.429" width="0.1524" layer="21"/>
<wire x1="-3.429" y1="3.429" x2="-3.429" y2="0.8915" width="0.1524" layer="21"/>
<wire x1="-3.429" y1="-0.8915" x2="-3.429" y2="-3.429" width="0.1524" layer="21"/>
<wire x1="3.429" y1="0.8915" x2="3.429" y2="3.429" width="0.1524" layer="21"/>
<wire x1="-4.6863" y1="0" x2="-4.8387" y2="0" width="0.1524" layer="21" curve="-180"/>
<wire x1="-4.8387" y1="0" x2="-4.6863" y2="0" width="0.1524" layer="21" curve="-180"/>
<wire x1="-3.302" y1="1.651" x2="-1.651" y2="3.302" width="0.1524" layer="51"/>
<wire x1="-3.302" y1="-1.651" x2="-1.651" y2="-3.302" width="0.1524" layer="51"/>
<wire x1="-3.302" y1="-3.302" x2="3.302" y2="-3.302" width="0.1524" layer="51"/>
<wire x1="3.302" y1="-3.302" x2="3.302" y2="3.302" width="0.1524" layer="51"/>
<wire x1="3.302" y1="3.302" x2="-3.302" y2="3.302" width="0.1524" layer="51"/>
<wire x1="-3.302" y1="3.302" x2="-3.302" y2="-3.302" width="0.1524" layer="51"/>
<wire x1="-2.7178" y1="0" x2="-2.8702" y2="0" width="0" layer="51" curve="-180"/>
<wire x1="-2.8702" y1="0" x2="-2.7178" y2="0" width="0" layer="51" curve="-180"/>
<polygon width="0.1524" layer="41" pour="solid">
<vertex x="-1.2573" y="-0.6096"/>
<vertex x="1.2573" y="-0.6096"/>
<vertex x="1.2573" y="0.6096"/>
<vertex x="-1.2573" y="0.6096"/>
</polygon>
<polygon width="0.1524" layer="41" pour="solid">
<vertex x="-3.2512" y="0.6096"/>
<vertex x="3.2512" y="0.6096"/>
<vertex x="3.2512" y="3.2512"/>
<vertex x="-3.2512" y="3.2512"/>
</polygon>
<polygon width="0.1524" layer="41" pour="solid">
<vertex x="-3.2512" y="-3.2512"/>
<vertex x="3.2512" y="-3.2512"/>
<vertex x="3.2512" y="-0.6096"/>
<vertex x="-3.2512" y="-0.6096"/>
</polygon>
<polygon width="0.1524" layer="41" pour="solid">
<vertex x="-1.2573" y="-0.6096"/>
<vertex x="1.2573" y="-0.6096"/>
<vertex x="1.2573" y="0.6096"/>
<vertex x="-1.2573" y="0.6096"/>
</polygon>
<text x="-3.2712" y="-0.635" size="1.27" layer="27" ratio="6">&gt;Name</text>
<text x="-1.7288" y="-0.635" size="1.27" layer="27" ratio="6">&gt;Value</text>
</package>
<package name="MIC_ICS-43432" library_version="23">
<wire x1="1.5" y1="2" x2="1.5" y2="-2" width="0.127" layer="51"/>
<wire x1="1.5" y1="-2" x2="-1.5" y2="-2" width="0.127" layer="51"/>
<wire x1="-1.5" y1="-2" x2="-1.5" y2="2" width="0.127" layer="51"/>
<wire x1="-1.5" y1="2" x2="1.5" y2="2" width="0.127" layer="51"/>
<rectangle x1="-1.325" y1="1.525" x2="-0.825" y2="1.825" layer="31"/>
<rectangle x1="0.825" y1="1.525" x2="1.325" y2="1.825" layer="31"/>
<rectangle x1="-1.325" y1="0.875" x2="-0.825" y2="1.175" layer="31"/>
<rectangle x1="0.825" y1="0.875" x2="1.325" y2="1.175" layer="31"/>
<rectangle x1="-1.325" y1="0.225" x2="-0.825" y2="0.525" layer="31"/>
<rectangle x1="0.825" y1="0.225" x2="1.325" y2="0.525" layer="31"/>
<polygon width="0.01" layer="1" pour="solid">
<vertex x="-0.160940625" y="-1.70915"/>
<vertex x="0" y="-1.725003125"/>
<vertex x="0.160940625" y="-1.70915"/>
<vertex x="0.315696875" y="-1.66220625"/>
<vertex x="0.45835" y="-1.5859625"/>
<vertex x="0.5833625" y="-1.4833625"/>
<vertex x="0.6859625" y="-1.35835"/>
<vertex x="0.76220625" y="-1.215696875"/>
<vertex x="0.80915" y="-1.060940625"/>
<vertex x="0.825" y="-0.9"/>
<vertex x="0.525" y="-0.9"/>
<vertex x="0.5120625" y="-1.014840625"/>
<vertex x="0.512334375" y="-1.01540625"/>
<vertex x="0.5118375" y="-1.016825"/>
<vertex x="0.51166875" y="-1.018328125"/>
<vertex x="0.511175" y="-1.018721875"/>
<vertex x="0.473671875" y="-1.125890625"/>
<vertex x="0.4738125" y="-1.12650625"/>
<vertex x="0.473009375" y="-1.12778125"/>
<vertex x="0.4725125" y="-1.12920625"/>
<vertex x="0.47194375" y="-1.12948125"/>
<vertex x="0.411525" y="-1.2256375"/>
<vertex x="0.411525" y="-1.226271875"/>
<vertex x="0.410453125" y="-1.22734375"/>
<vertex x="0.40965625" y="-1.2286125"/>
<vertex x="0.40904375" y="-1.228753125"/>
<vertex x="0.328753125" y="-1.30904375"/>
<vertex x="0.3286125" y="-1.30965625"/>
<vertex x="0.32734375" y="-1.310453125"/>
<vertex x="0.326271875" y="-1.311525"/>
<vertex x="0.3256375" y="-1.311525"/>
<vertex x="0.22948125" y="-1.37194375"/>
<vertex x="0.22920625" y="-1.3725125"/>
<vertex x="0.22778125" y="-1.373009375"/>
<vertex x="0.22650625" y="-1.3738125"/>
<vertex x="0.225890625" y="-1.373671875"/>
<vertex x="0.118721875" y="-1.411175"/>
<vertex x="0.118328125" y="-1.41166875"/>
<vertex x="0.116825" y="-1.4118375"/>
<vertex x="0.11540625" y="-1.412334375"/>
<vertex x="0.114840625" y="-1.4120625"/>
<vertex x="0.001990625" y="-1.424775"/>
<vertex x="0.001496875" y="-1.42516875"/>
<vertex x="0" y="-1.425"/>
<vertex x="-0.001496875" y="-1.42516875"/>
<vertex x="-0.001990625" y="-1.424775"/>
<vertex x="-0.114840625" y="-1.4120625"/>
<vertex x="-0.11540625" y="-1.412334375"/>
<vertex x="-0.116825" y="-1.4118375"/>
<vertex x="-0.118328125" y="-1.41166875"/>
<vertex x="-0.118721875" y="-1.411175"/>
<vertex x="-0.225890625" y="-1.373671875"/>
<vertex x="-0.22650625" y="-1.3738125"/>
<vertex x="-0.22778125" y="-1.373009375"/>
<vertex x="-0.22920625" y="-1.3725125"/>
<vertex x="-0.22948125" y="-1.37194375"/>
<vertex x="-0.3256375" y="-1.311525"/>
<vertex x="-0.326271875" y="-1.311525"/>
<vertex x="-0.32734375" y="-1.310453125"/>
<vertex x="-0.3286125" y="-1.30965625"/>
<vertex x="-0.328753125" y="-1.30904375"/>
<vertex x="-0.40904375" y="-1.228753125"/>
<vertex x="-0.40965625" y="-1.2286125"/>
<vertex x="-0.410453125" y="-1.22734375"/>
<vertex x="-0.411525" y="-1.226271875"/>
<vertex x="-0.411525" y="-1.2256375"/>
<vertex x="-0.47194375" y="-1.12948125"/>
<vertex x="-0.4725125" y="-1.12920625"/>
<vertex x="-0.473009375" y="-1.12778125"/>
<vertex x="-0.4738125" y="-1.12650625"/>
<vertex x="-0.473671875" y="-1.125890625"/>
<vertex x="-0.511175" y="-1.018721875"/>
<vertex x="-0.51166875" y="-1.018328125"/>
<vertex x="-0.5118375" y="-1.016825"/>
<vertex x="-0.512334375" y="-1.01540625"/>
<vertex x="-0.5120625" y="-1.014840625"/>
<vertex x="-0.525" y="-0.9"/>
<vertex x="-0.825" y="-0.9"/>
<vertex x="-0.80915" y="-1.060940625"/>
<vertex x="-0.76220625" y="-1.215696875"/>
<vertex x="-0.6859625" y="-1.35835"/>
<vertex x="-0.5833625" y="-1.4833625"/>
<vertex x="-0.45835" y="-1.5859625"/>
<vertex x="-0.315696875" y="-1.66220625"/>
</polygon>
<polygon width="0.01" layer="1" pour="solid">
<vertex x="0.525" y="-0.9"/>
<vertex x="0.825" y="-0.9"/>
<vertex x="0.80915" y="-0.739059375"/>
<vertex x="0.76220625" y="-0.584303125"/>
<vertex x="0.6859625" y="-0.44165"/>
<vertex x="0.5833625" y="-0.3166375"/>
<vertex x="0.45835" y="-0.2140375"/>
<vertex x="0.315696875" y="-0.13779375"/>
<vertex x="0.160940625" y="-0.09085"/>
<vertex x="0" y="-0.074996875"/>
<vertex x="-0.160940625" y="-0.09085"/>
<vertex x="-0.315696875" y="-0.13779375"/>
<vertex x="-0.45835" y="-0.2140375"/>
<vertex x="-0.5833625" y="-0.3166375"/>
<vertex x="-0.6859625" y="-0.44165"/>
<vertex x="-0.76220625" y="-0.584303125"/>
<vertex x="-0.80915" y="-0.739059375"/>
<vertex x="-0.825" y="-0.9"/>
<vertex x="-0.525" y="-0.9"/>
<vertex x="-0.5120625" y="-0.785159375"/>
<vertex x="-0.512334375" y="-0.78459375"/>
<vertex x="-0.5118375" y="-0.783175"/>
<vertex x="-0.51166875" y="-0.781671875"/>
<vertex x="-0.511175" y="-0.781278125"/>
<vertex x="-0.473671875" y="-0.674109375"/>
<vertex x="-0.4738125" y="-0.67349375"/>
<vertex x="-0.473009375" y="-0.67221875"/>
<vertex x="-0.4725125" y="-0.67079375"/>
<vertex x="-0.47194375" y="-0.67051875"/>
<vertex x="-0.411525" y="-0.5743625"/>
<vertex x="-0.411525" y="-0.573728125"/>
<vertex x="-0.410453125" y="-0.57265625"/>
<vertex x="-0.40965625" y="-0.5713875"/>
<vertex x="-0.40904375" y="-0.571246875"/>
<vertex x="-0.328753125" y="-0.49095625"/>
<vertex x="-0.3286125" y="-0.49034375"/>
<vertex x="-0.32734375" y="-0.489546875"/>
<vertex x="-0.326271875" y="-0.488475"/>
<vertex x="-0.3256375" y="-0.488475"/>
<vertex x="-0.22948125" y="-0.42805625"/>
<vertex x="-0.22920625" y="-0.4274875"/>
<vertex x="-0.22778125" y="-0.426990625"/>
<vertex x="-0.22650625" y="-0.4261875"/>
<vertex x="-0.225890625" y="-0.426328125"/>
<vertex x="-0.118721875" y="-0.388825"/>
<vertex x="-0.118328125" y="-0.38833125"/>
<vertex x="-0.116825" y="-0.3881625"/>
<vertex x="-0.11540625" y="-0.387665625"/>
<vertex x="-0.114840625" y="-0.3879375"/>
<vertex x="-0.001990625" y="-0.375225"/>
<vertex x="-0.001496875" y="-0.37483125"/>
<vertex x="0" y="-0.375"/>
<vertex x="0.001496875" y="-0.37483125"/>
<vertex x="0.001990625" y="-0.375225"/>
<vertex x="0.114840625" y="-0.3879375"/>
<vertex x="0.11540625" y="-0.387665625"/>
<vertex x="0.116825" y="-0.3881625"/>
<vertex x="0.118328125" y="-0.38833125"/>
<vertex x="0.118721875" y="-0.388825"/>
<vertex x="0.225890625" y="-0.426328125"/>
<vertex x="0.22650625" y="-0.4261875"/>
<vertex x="0.22778125" y="-0.426990625"/>
<vertex x="0.22920625" y="-0.4274875"/>
<vertex x="0.22948125" y="-0.42805625"/>
<vertex x="0.3256375" y="-0.488475"/>
<vertex x="0.326271875" y="-0.488475"/>
<vertex x="0.32734375" y="-0.489546875"/>
<vertex x="0.3286125" y="-0.49034375"/>
<vertex x="0.328753125" y="-0.49095625"/>
<vertex x="0.40904375" y="-0.571246875"/>
<vertex x="0.40965625" y="-0.5713875"/>
<vertex x="0.410453125" y="-0.57265625"/>
<vertex x="0.411525" y="-0.573728125"/>
<vertex x="0.411525" y="-0.5743625"/>
<vertex x="0.47194375" y="-0.67051875"/>
<vertex x="0.4725125" y="-0.67079375"/>
<vertex x="0.473009375" y="-0.67221875"/>
<vertex x="0.4738125" y="-0.67349375"/>
<vertex x="0.473671875" y="-0.674109375"/>
<vertex x="0.511175" y="-0.781278125"/>
<vertex x="0.51166875" y="-0.781671875"/>
<vertex x="0.5118375" y="-0.783175"/>
<vertex x="0.512334375" y="-0.78459375"/>
<vertex x="0.5120625" y="-0.785159375"/>
</polygon>
<polygon width="0.01" layer="31" pour="solid">
<vertex x="-0.823484375" y="-0.85"/>
<vertex x="-0.572821875" y="-0.85"/>
<vertex x="-0.551921875" y="-0.739434375"/>
<vertex x="-0.552140625" y="-0.7389125"/>
<vertex x="-0.551546875" y="-0.737453125"/>
<vertex x="-0.55125625" y="-0.735915625"/>
<vertex x="-0.55079375" y="-0.7356"/>
<vertex x="-0.50914375" y="-0.633228125"/>
<vertex x="-0.50925625" y="-0.632675"/>
<vertex x="-0.508384375" y="-0.6313625"/>
<vertex x="-0.50779375" y="-0.629909375"/>
<vertex x="-0.507275" y="-0.629690625"/>
<vertex x="-0.446165625" y="-0.537596875"/>
<vertex x="-0.446165625" y="-0.537034375"/>
<vertex x="-0.44505625" y="-0.535925"/>
<vertex x="-0.4441875" y="-0.534615625"/>
<vertex x="-0.443634375" y="-0.534503125"/>
<vertex x="-0.365496875" y="-0.456365625"/>
<vertex x="-0.365384375" y="-0.4558125"/>
<vertex x="-0.364075" y="-0.45494375"/>
<vertex x="-0.362965625" y="-0.453834375"/>
<vertex x="-0.362403125" y="-0.453834375"/>
<vertex x="-0.270309375" y="-0.392725"/>
<vertex x="-0.270090625" y="-0.39220625"/>
<vertex x="-0.2686375" y="-0.391615625"/>
<vertex x="-0.267325" y="-0.39074375"/>
<vertex x="-0.266771875" y="-0.39085625"/>
<vertex x="-0.1644" y="-0.34920625"/>
<vertex x="-0.164084375" y="-0.34874375"/>
<vertex x="-0.162546875" y="-0.348453125"/>
<vertex x="-0.1610875" y="-0.347859375"/>
<vertex x="-0.160565625" y="-0.348078125"/>
<vertex x="-0.05" y="-0.327178125"/>
<vertex x="-0.05" y="-0.076515625"/>
<vertex x="-0.2182375" y="-0.1043875"/>
<vertex x="-0.377134375" y="-0.166246875"/>
<vertex x="-0.519946875" y="-0.25946875"/>
<vertex x="-0.64053125" y="-0.380053125"/>
<vertex x="-0.733753125" y="-0.522865625"/>
<vertex x="-0.7956125" y="-0.6817625"/>
</polygon>
<polygon width="0.01" layer="31" pour="solid">
<vertex x="0.572821875" y="-0.85"/>
<vertex x="0.823484375" y="-0.85"/>
<vertex x="0.7956125" y="-0.6817625"/>
<vertex x="0.733753125" y="-0.522865625"/>
<vertex x="0.64053125" y="-0.380053125"/>
<vertex x="0.519946875" y="-0.25946875"/>
<vertex x="0.377134375" y="-0.166246875"/>
<vertex x="0.2182375" y="-0.1043875"/>
<vertex x="0.05" y="-0.076515625"/>
<vertex x="0.05" y="-0.327178125"/>
<vertex x="0.160565625" y="-0.348078125"/>
<vertex x="0.1610875" y="-0.347859375"/>
<vertex x="0.162546875" y="-0.348453125"/>
<vertex x="0.164084375" y="-0.34874375"/>
<vertex x="0.1644" y="-0.34920625"/>
<vertex x="0.266771875" y="-0.39085625"/>
<vertex x="0.267325" y="-0.39074375"/>
<vertex x="0.2686375" y="-0.391615625"/>
<vertex x="0.270090625" y="-0.39220625"/>
<vertex x="0.270309375" y="-0.392725"/>
<vertex x="0.362403125" y="-0.453834375"/>
<vertex x="0.362965625" y="-0.453834375"/>
<vertex x="0.364075" y="-0.45494375"/>
<vertex x="0.365384375" y="-0.4558125"/>
<vertex x="0.365496875" y="-0.456365625"/>
<vertex x="0.443634375" y="-0.534503125"/>
<vertex x="0.4441875" y="-0.534615625"/>
<vertex x="0.44505625" y="-0.535925"/>
<vertex x="0.446165625" y="-0.537034375"/>
<vertex x="0.446165625" y="-0.537596875"/>
<vertex x="0.507275" y="-0.629690625"/>
<vertex x="0.50779375" y="-0.629909375"/>
<vertex x="0.508384375" y="-0.6313625"/>
<vertex x="0.50925625" y="-0.632675"/>
<vertex x="0.50914375" y="-0.633228125"/>
<vertex x="0.55079375" y="-0.7356"/>
<vertex x="0.55125625" y="-0.735915625"/>
<vertex x="0.551546875" y="-0.737453125"/>
<vertex x="0.552140625" y="-0.7389125"/>
<vertex x="0.551921875" y="-0.739434375"/>
</polygon>
<polygon width="0.01" layer="31" pour="solid">
<vertex x="-0.2182375" y="-1.695609375"/>
<vertex x="-0.05" y="-1.72348125"/>
<vertex x="-0.05" y="-1.47281875"/>
<vertex x="-0.1605625" y="-1.45191875"/>
<vertex x="-0.161084375" y="-1.4521375"/>
<vertex x="-0.16254375" y="-1.45154375"/>
<vertex x="-0.16408125" y="-1.451253125"/>
<vertex x="-0.164396875" y="-1.450790625"/>
<vertex x="-0.266771875" y="-1.40914375"/>
<vertex x="-0.267325" y="-1.40925625"/>
<vertex x="-0.2686375" y="-1.408384375"/>
<vertex x="-0.270090625" y="-1.40779375"/>
<vertex x="-0.270309375" y="-1.407275"/>
<vertex x="-0.362403125" y="-1.3461625"/>
<vertex x="-0.362965625" y="-1.3461625"/>
<vertex x="-0.364075" y="-1.345053125"/>
<vertex x="-0.365384375" y="-1.344184375"/>
<vertex x="-0.365496875" y="-1.34363125"/>
<vertex x="-0.443634375" y="-1.265496875"/>
<vertex x="-0.4441875" y="-1.265384375"/>
<vertex x="-0.44505625" y="-1.264075"/>
<vertex x="-0.446165625" y="-1.262965625"/>
<vertex x="-0.446165625" y="-1.262403125"/>
<vertex x="-0.507275" y="-1.170309375"/>
<vertex x="-0.50779375" y="-1.170090625"/>
<vertex x="-0.508384375" y="-1.1686375"/>
<vertex x="-0.50925625" y="-1.167325"/>
<vertex x="-0.50914375" y="-1.166771875"/>
<vertex x="-0.55079375" y="-1.064396875"/>
<vertex x="-0.55125625" y="-1.06408125"/>
<vertex x="-0.551546875" y="-1.06254375"/>
<vertex x="-0.552140625" y="-1.061084375"/>
<vertex x="-0.551921875" y="-1.0605625"/>
<vertex x="-0.572821875" y="-0.95"/>
<vertex x="-0.823484375" y="-0.95"/>
<vertex x="-0.7956125" y="-1.1182375"/>
<vertex x="-0.733753125" y="-1.277134375"/>
<vertex x="-0.64053125" y="-1.419946875"/>
<vertex x="-0.519946875" y="-1.540528125"/>
<vertex x="-0.377134375" y="-1.63375"/>
</polygon>
<polygon width="0.01" layer="31" pour="solid">
<vertex x="0.05" y="-1.47281875"/>
<vertex x="0.05" y="-1.72348125"/>
<vertex x="0.2182375" y="-1.695609375"/>
<vertex x="0.377134375" y="-1.63375"/>
<vertex x="0.519946875" y="-1.540528125"/>
<vertex x="0.64053125" y="-1.419946875"/>
<vertex x="0.733753125" y="-1.277134375"/>
<vertex x="0.7956125" y="-1.1182375"/>
<vertex x="0.823484375" y="-0.95"/>
<vertex x="0.572821875" y="-0.95"/>
<vertex x="0.551921875" y="-1.0605625"/>
<vertex x="0.552140625" y="-1.061084375"/>
<vertex x="0.551546875" y="-1.06254375"/>
<vertex x="0.55125625" y="-1.06408125"/>
<vertex x="0.55079375" y="-1.064396875"/>
<vertex x="0.50914375" y="-1.166771875"/>
<vertex x="0.50925625" y="-1.167325"/>
<vertex x="0.508384375" y="-1.1686375"/>
<vertex x="0.50779375" y="-1.170090625"/>
<vertex x="0.507275" y="-1.170309375"/>
<vertex x="0.446165625" y="-1.262403125"/>
<vertex x="0.446165625" y="-1.262965625"/>
<vertex x="0.44505625" y="-1.264075"/>
<vertex x="0.4441875" y="-1.265384375"/>
<vertex x="0.443634375" y="-1.265496875"/>
<vertex x="0.365496875" y="-1.34363125"/>
<vertex x="0.365384375" y="-1.344184375"/>
<vertex x="0.364075" y="-1.345053125"/>
<vertex x="0.362965625" y="-1.3461625"/>
<vertex x="0.362403125" y="-1.3461625"/>
<vertex x="0.270309375" y="-1.407275"/>
<vertex x="0.270090625" y="-1.40779375"/>
<vertex x="0.2686375" y="-1.408384375"/>
<vertex x="0.267325" y="-1.40925625"/>
<vertex x="0.266771875" y="-1.40914375"/>
<vertex x="0.164396875" y="-1.450790625"/>
<vertex x="0.16408125" y="-1.451253125"/>
<vertex x="0.16254375" y="-1.45154375"/>
<vertex x="0.161084375" y="-1.4521375"/>
<vertex x="0.1605625" y="-1.45191875"/>
</polygon>
<polygon width="0.01" layer="29" pour="solid">
<vertex x="0.475" y="-0.9"/>
<vertex x="0.875" y="-0.9"/>
<vertex x="0.858190625" y="-0.72930625"/>
<vertex x="0.8084" y="-0.56516875"/>
<vertex x="0.727534375" y="-0.413871875"/>
<vertex x="0.61871875" y="-0.28128125"/>
<vertex x="0.486128125" y="-0.172465625"/>
<vertex x="0.33483125" y="-0.0916"/>
<vertex x="0.17069375" y="-0.041809375"/>
<vertex x="0" y="-0.024996875"/>
<vertex x="-0.17069375" y="-0.041809375"/>
<vertex x="-0.33483125" y="-0.0916"/>
<vertex x="-0.486128125" y="-0.172465625"/>
<vertex x="-0.61871875" y="-0.28128125"/>
<vertex x="-0.727534375" y="-0.413871875"/>
<vertex x="-0.8084" y="-0.56516875"/>
<vertex x="-0.858190625" y="-0.72930625"/>
<vertex x="-0.875" y="-0.9"/>
<vertex x="-0.475" y="-0.9"/>
<vertex x="-0.463315625" y="-0.7962875"/>
<vertex x="-0.4635875" y="-0.795721875"/>
<vertex x="-0.463090625" y="-0.794303125"/>
<vertex x="-0.462921875" y="-0.7928"/>
<vertex x="-0.462428125" y="-0.79240625"/>
<vertex x="-0.428621875" y="-0.695803125"/>
<vertex x="-0.4287625" y="-0.6951875"/>
<vertex x="-0.427959375" y="-0.6939125"/>
<vertex x="-0.4274625" y="-0.6924875"/>
<vertex x="-0.42689375" y="-0.6922125"/>
<vertex x="-0.37243125" y="-0.6055375"/>
<vertex x="-0.37243125" y="-0.604903125"/>
<vertex x="-0.371359375" y="-0.60383125"/>
<vertex x="-0.3705625" y="-0.6025625"/>
<vertex x="-0.36995" y="-0.602421875"/>
<vertex x="-0.297578125" y="-0.53005"/>
<vertex x="-0.2974375" y="-0.5294375"/>
<vertex x="-0.29616875" y="-0.528640625"/>
<vertex x="-0.295096875" y="-0.52756875"/>
<vertex x="-0.2944625" y="-0.52756875"/>
<vertex x="-0.2077875" y="-0.47310625"/>
<vertex x="-0.2075125" y="-0.4725375"/>
<vertex x="-0.2060875" y="-0.472040625"/>
<vertex x="-0.2048125" y="-0.4712375"/>
<vertex x="-0.204196875" y="-0.471378125"/>
<vertex x="-0.10759375" y="-0.437571875"/>
<vertex x="-0.1072" y="-0.437078125"/>
<vertex x="-0.105696875" y="-0.436909375"/>
<vertex x="-0.104278125" y="-0.4364125"/>
<vertex x="-0.1037125" y="-0.436684375"/>
<vertex x="-0.001990625" y="-0.425225"/>
<vertex x="-0.001496875" y="-0.42483125"/>
<vertex x="0" y="-0.425"/>
<vertex x="0.001496875" y="-0.42483125"/>
<vertex x="0.001990625" y="-0.425225"/>
<vertex x="0.1037125" y="-0.436684375"/>
<vertex x="0.104278125" y="-0.4364125"/>
<vertex x="0.105696875" y="-0.436909375"/>
<vertex x="0.1072" y="-0.437078125"/>
<vertex x="0.10759375" y="-0.437571875"/>
<vertex x="0.204196875" y="-0.471378125"/>
<vertex x="0.2048125" y="-0.4712375"/>
<vertex x="0.2060875" y="-0.472040625"/>
<vertex x="0.2075125" y="-0.4725375"/>
<vertex x="0.2077875" y="-0.47310625"/>
<vertex x="0.2944625" y="-0.52756875"/>
<vertex x="0.295096875" y="-0.52756875"/>
<vertex x="0.29616875" y="-0.528640625"/>
<vertex x="0.2974375" y="-0.5294375"/>
<vertex x="0.297578125" y="-0.53005"/>
<vertex x="0.36995" y="-0.602421875"/>
<vertex x="0.3705625" y="-0.6025625"/>
<vertex x="0.371359375" y="-0.60383125"/>
<vertex x="0.37243125" y="-0.604903125"/>
<vertex x="0.37243125" y="-0.6055375"/>
<vertex x="0.42689375" y="-0.6922125"/>
<vertex x="0.4274625" y="-0.6924875"/>
<vertex x="0.427959375" y="-0.6939125"/>
<vertex x="0.4287625" y="-0.6951875"/>
<vertex x="0.428621875" y="-0.695803125"/>
<vertex x="0.462428125" y="-0.79240625"/>
<vertex x="0.462921875" y="-0.7928"/>
<vertex x="0.463090625" y="-0.794303125"/>
<vertex x="0.4635875" y="-0.795721875"/>
<vertex x="0.463315625" y="-0.7962875"/>
</polygon>
<polygon width="0.01" layer="29" pour="solid">
<vertex x="-0.17069375" y="-1.758190625"/>
<vertex x="0" y="-1.775003125"/>
<vertex x="0.17069375" y="-1.758190625"/>
<vertex x="0.33483125" y="-1.7084"/>
<vertex x="0.486128125" y="-1.627534375"/>
<vertex x="0.61871875" y="-1.51871875"/>
<vertex x="0.727534375" y="-1.386128125"/>
<vertex x="0.8084" y="-1.23483125"/>
<vertex x="0.858190625" y="-1.07069375"/>
<vertex x="0.875" y="-0.9"/>
<vertex x="0.475" y="-0.9"/>
<vertex x="0.463315625" y="-1.0037125"/>
<vertex x="0.4635875" y="-1.004278125"/>
<vertex x="0.463090625" y="-1.005696875"/>
<vertex x="0.462921875" y="-1.0072"/>
<vertex x="0.462428125" y="-1.00759375"/>
<vertex x="0.428621875" y="-1.104196875"/>
<vertex x="0.4287625" y="-1.1048125"/>
<vertex x="0.427959375" y="-1.1060875"/>
<vertex x="0.4274625" y="-1.1075125"/>
<vertex x="0.42689375" y="-1.1077875"/>
<vertex x="0.37243125" y="-1.1944625"/>
<vertex x="0.37243125" y="-1.195096875"/>
<vertex x="0.371359375" y="-1.19616875"/>
<vertex x="0.3705625" y="-1.1974375"/>
<vertex x="0.36995" y="-1.197578125"/>
<vertex x="0.297578125" y="-1.26995"/>
<vertex x="0.2974375" y="-1.2705625"/>
<vertex x="0.29616875" y="-1.271359375"/>
<vertex x="0.295096875" y="-1.27243125"/>
<vertex x="0.2944625" y="-1.27243125"/>
<vertex x="0.2077875" y="-1.32689375"/>
<vertex x="0.2075125" y="-1.3274625"/>
<vertex x="0.2060875" y="-1.327959375"/>
<vertex x="0.2048125" y="-1.3287625"/>
<vertex x="0.204196875" y="-1.328621875"/>
<vertex x="0.10759375" y="-1.362428125"/>
<vertex x="0.1072" y="-1.362921875"/>
<vertex x="0.105696875" y="-1.363090625"/>
<vertex x="0.104278125" y="-1.3635875"/>
<vertex x="0.1037125" y="-1.363315625"/>
<vertex x="0.001990625" y="-1.374775"/>
<vertex x="0.001496875" y="-1.37516875"/>
<vertex x="0" y="-1.375"/>
<vertex x="-0.001496875" y="-1.37516875"/>
<vertex x="-0.001990625" y="-1.374775"/>
<vertex x="-0.1037125" y="-1.363315625"/>
<vertex x="-0.104278125" y="-1.3635875"/>
<vertex x="-0.105696875" y="-1.363090625"/>
<vertex x="-0.1072" y="-1.362921875"/>
<vertex x="-0.10759375" y="-1.362428125"/>
<vertex x="-0.204196875" y="-1.328621875"/>
<vertex x="-0.2048125" y="-1.3287625"/>
<vertex x="-0.2060875" y="-1.327959375"/>
<vertex x="-0.2075125" y="-1.3274625"/>
<vertex x="-0.2077875" y="-1.32689375"/>
<vertex x="-0.2944625" y="-1.27243125"/>
<vertex x="-0.295096875" y="-1.27243125"/>
<vertex x="-0.29616875" y="-1.271359375"/>
<vertex x="-0.2974375" y="-1.2705625"/>
<vertex x="-0.297578125" y="-1.26995"/>
<vertex x="-0.36995" y="-1.197578125"/>
<vertex x="-0.3705625" y="-1.1974375"/>
<vertex x="-0.371359375" y="-1.19616875"/>
<vertex x="-0.37243125" y="-1.195096875"/>
<vertex x="-0.37243125" y="-1.1944625"/>
<vertex x="-0.42689375" y="-1.1077875"/>
<vertex x="-0.4274625" y="-1.1075125"/>
<vertex x="-0.427959375" y="-1.1060875"/>
<vertex x="-0.4287625" y="-1.1048125"/>
<vertex x="-0.428621875" y="-1.104196875"/>
<vertex x="-0.462428125" y="-1.00759375"/>
<vertex x="-0.462921875" y="-1.0072"/>
<vertex x="-0.463090625" y="-1.005696875"/>
<vertex x="-0.4635875" y="-1.004278125"/>
<vertex x="-0.463315625" y="-1.0037125"/>
<vertex x="-0.475" y="-0.9"/>
<vertex x="-0.875" y="-0.9"/>
<vertex x="-0.858190625" y="-1.07069375"/>
<vertex x="-0.8084" y="-1.23483125"/>
<vertex x="-0.727534375" y="-1.386128125"/>
<vertex x="-0.61871875" y="-1.51871875"/>
<vertex x="-0.486128125" y="-1.627534375"/>
<vertex x="-0.33483125" y="-1.7084"/>
</polygon>
<wire x1="1.5" y1="-2" x2="1.5" y2="-0.145" width="0.127" layer="21"/>
<wire x1="-0.37" y1="-2" x2="-1.5" y2="-2" width="0.127" layer="21"/>
<wire x1="1.5" y1="-2" x2="0.37" y2="-2" width="0.127" layer="21"/>
<wire x1="-1.5" y1="-2" x2="-1.5" y2="-0.145" width="0.127" layer="21"/>
<wire x1="-1.75" y1="2.25" x2="-1.75" y2="-2.25" width="0.05" layer="39"/>
<wire x1="-1.75" y1="-2.25" x2="1.75" y2="-2.25" width="0.05" layer="39"/>
<wire x1="1.75" y1="-2.25" x2="1.75" y2="2.25" width="0.05" layer="39"/>
<wire x1="1.75" y1="2.25" x2="-1.75" y2="2.25" width="0.05" layer="39"/>
<circle x="-2.075" y="1.675" radius="0.1" width="0.2" layer="21"/>
<circle x="-2.075" y="1.675" radius="0.1" width="0.2" layer="51"/>
<text x="-1.75" y="2.45" size="1.27" layer="25">&gt;NAME</text>
<text x="-1.75" y="-2.65" size="1.27" layer="27" align="top-left">&gt;VALUE</text>
<wire x1="-0.455" y1="2" x2="0.455" y2="2" width="0.127" layer="21"/>
<smd name="1" x="-1.075" y="1.675" dx="0.6" dy="0.4" layer="1" cream="no"/>
<smd name="4" x="0" y="-1.58" dx="0.24" dy="0.24" layer="1" stop="no" thermals="no" cream="no"/>
<smd name="2" x="-1.075" y="1.025" dx="0.6" dy="0.4" layer="1" cream="no"/>
<smd name="3" x="-1.075" y="0.375" dx="0.6" dy="0.4" layer="1" cream="no"/>
<smd name="7" x="1.075" y="1.675" dx="0.6" dy="0.4" layer="1" cream="no"/>
<smd name="6" x="1.075" y="1.025" dx="0.6" dy="0.4" layer="1" cream="no"/>
<smd name="5" x="1.075" y="0.375" dx="0.6" dy="0.4" layer="1" cream="no"/>
<hole x="0" y="-0.9" drill="0.5"/>
</package>
<package name="GCT_USB4120-03-C_REVA6" library_version="25">
<wire x1="3.65" y1="0.26" x2="3.85" y2="0.26" width="0" layer="46"/>
<wire x1="3.85" y1="0.26" x2="4.11" y2="0" width="0" layer="46" curve="-90"/>
<wire x1="4.11" y1="0" x2="3.85" y2="-0.26" width="0" layer="46" curve="-90"/>
<wire x1="3.85" y1="-0.26" x2="3.65" y2="-0.26" width="0" layer="46"/>
<wire x1="3.65" y1="-0.26" x2="3.39" y2="0" width="0" layer="46" curve="-90"/>
<wire x1="3.39" y1="0" x2="3.65" y2="0.26" width="0" layer="46" curve="-90"/>
<wire x1="-2.525" y1="2.45" x2="-2.275" y2="2.45" width="0" layer="46"/>
<wire x1="-2.275" y1="2.45" x2="-1.975" y2="2.15" width="0" layer="46" curve="-90"/>
<wire x1="-1.975" y1="2.15" x2="-2.275" y2="1.85" width="0" layer="46" curve="-90"/>
<wire x1="-2.275" y1="1.85" x2="-2.525" y2="1.85" width="0" layer="46"/>
<wire x1="-2.525" y1="1.85" x2="-2.825" y2="2.15" width="0" layer="46" curve="-90"/>
<wire x1="-2.825" y1="2.15" x2="-2.525" y2="2.45" width="0" layer="46" curve="-90"/>
<wire x1="-2.525" y1="-1.85" x2="-2.275" y2="-1.85" width="0" layer="46"/>
<wire x1="-2.275" y1="-1.85" x2="-1.975" y2="-2.15" width="0" layer="46" curve="-90"/>
<wire x1="-1.975" y1="-2.15" x2="-2.275" y2="-2.45" width="0" layer="46" curve="-90"/>
<wire x1="-2.275" y1="-2.45" x2="-2.525" y2="-2.45" width="0" layer="46"/>
<wire x1="-2.525" y1="-2.45" x2="-2.825" y2="-2.15" width="0" layer="46" curve="-90"/>
<wire x1="-2.825" y1="-2.15" x2="-2.525" y2="-1.85" width="0" layer="46" curve="-90"/>
<wire x1="2.275" y1="2.45" x2="2.525" y2="2.45" width="0" layer="46"/>
<wire x1="2.525" y1="2.45" x2="2.825" y2="2.15" width="0" layer="46" curve="-90"/>
<wire x1="2.825" y1="2.15" x2="2.525" y2="1.85" width="0" layer="46" curve="-90"/>
<wire x1="2.525" y1="1.85" x2="2.275" y2="1.85" width="0" layer="46"/>
<wire x1="2.275" y1="1.85" x2="1.975" y2="2.15" width="0" layer="46" curve="-90"/>
<wire x1="1.975" y1="2.15" x2="2.275" y2="2.45" width="0" layer="46" curve="-90"/>
<wire x1="2.275" y1="-1.85" x2="2.525" y2="-1.85" width="0" layer="46"/>
<wire x1="2.525" y1="-1.85" x2="2.825" y2="-2.15" width="0" layer="46" curve="-90"/>
<wire x1="2.825" y1="-2.15" x2="2.525" y2="-2.45" width="0" layer="46" curve="-90"/>
<wire x1="2.525" y1="-2.45" x2="2.275" y2="-2.45" width="0" layer="46"/>
<wire x1="2.275" y1="-2.45" x2="1.975" y2="-2.15" width="0" layer="46" curve="-90"/>
<wire x1="1.975" y1="-2.15" x2="2.275" y2="-1.85" width="0" layer="46" curve="-90"/>
<wire x1="-4.47" y1="1.58" x2="4.47" y2="1.58" width="0.1" layer="51"/>
<wire x1="4.47" y1="1.58" x2="4.47" y2="-1.58" width="0.1" layer="51"/>
<wire x1="4.47" y1="-1.58" x2="-4.47" y2="-1.58" width="0.1" layer="51"/>
<wire x1="-4.47" y1="-1.58" x2="-4.47" y2="1.58" width="0.1" layer="51"/>
<wire x1="-3.75" y1="1.58" x2="-4.47" y2="1.58" width="0.2" layer="21"/>
<wire x1="-4.47" y1="1.58" x2="-4.47" y2="-1.58" width="0.2" layer="21"/>
<wire x1="-4.47" y1="-1.58" x2="-3.75" y2="-1.58" width="0.2" layer="21"/>
<wire x1="3.75" y1="1.58" x2="4.47" y2="1.58" width="0.2" layer="21"/>
<wire x1="4.47" y1="1.58" x2="4.47" y2="-1.58" width="0.2" layer="21"/>
<wire x1="4.47" y1="-1.58" x2="3.75" y2="-1.58" width="0.2" layer="21"/>
<circle x="-5" y="0.9" radius="0.1" width="0.2" layer="21"/>
<circle x="-5" y="0.9" radius="0.1" width="0.2" layer="51"/>
<wire x1="-4.72" y1="2.95" x2="4.72" y2="2.95" width="0.05" layer="39"/>
<wire x1="4.72" y1="2.95" x2="4.72" y2="-2.95" width="0.05" layer="39"/>
<wire x1="4.72" y1="-2.95" x2="-4.72" y2="-2.95" width="0.05" layer="39"/>
<wire x1="-4.72" y1="-2.95" x2="-4.72" y2="2.95" width="0.05" layer="39"/>
<text x="-4.699" y="3.302" size="1.27" layer="25">&gt;NAME</text>
<text x="-4.826" y="-4.445" size="1.27" layer="27">&gt;VALUE</text>
<polygon width="0.01" layer="1" pour="solid">
<vertex x="-2.5250125" y="1.6"/>
<vertex x="-2.2749875" y="1.6"/>
<vertex x="-2.167709375" y="1.610565625"/>
<vertex x="-2.064540625" y="1.641859375"/>
<vertex x="-1.969434375" y="1.692690625"/>
<vertex x="-1.886090625" y="1.761090625"/>
<vertex x="-1.817690625" y="1.844434375"/>
<vertex x="-1.766859375" y="1.939540625"/>
<vertex x="-1.735565625" y="2.042709375"/>
<vertex x="-1.724996875" y="2.15"/>
<vertex x="-1.735565625" y="2.257290625"/>
<vertex x="-1.766859375" y="2.360459375"/>
<vertex x="-1.817690625" y="2.455565625"/>
<vertex x="-1.886090625" y="2.538909375"/>
<vertex x="-1.969434375" y="2.607309375"/>
<vertex x="-2.064540625" y="2.658140625"/>
<vertex x="-2.167709375" y="2.689434375"/>
<vertex x="-2.2749875" y="2.7"/>
<vertex x="-2.5250125" y="2.7"/>
<vertex x="-2.632290625" y="2.689434375"/>
<vertex x="-2.735459375" y="2.658140625"/>
<vertex x="-2.830565625" y="2.607309375"/>
<vertex x="-2.913909375" y="2.538909375"/>
<vertex x="-2.982309375" y="2.455565625"/>
<vertex x="-3.033140625" y="2.360459375"/>
<vertex x="-3.064434375" y="2.257290625"/>
<vertex x="-3.075003125" y="2.15"/>
<vertex x="-3.064434375" y="2.042709375"/>
<vertex x="-3.033140625" y="1.939540625"/>
<vertex x="-2.982309375" y="1.844434375"/>
<vertex x="-2.913909375" y="1.761090625"/>
<vertex x="-2.830565625" y="1.692690625"/>
<vertex x="-2.735459375" y="1.641859375"/>
<vertex x="-2.632290625" y="1.610565625"/>
</polygon>
<polygon width="0.01" layer="1" pour="solid">
<vertex x="-2.5250125" y="-2.7"/>
<vertex x="-2.2749875" y="-2.7"/>
<vertex x="-2.167709375" y="-2.689434375"/>
<vertex x="-2.064540625" y="-2.658140625"/>
<vertex x="-1.969434375" y="-2.607309375"/>
<vertex x="-1.886090625" y="-2.538909375"/>
<vertex x="-1.817690625" y="-2.455565625"/>
<vertex x="-1.766859375" y="-2.360459375"/>
<vertex x="-1.735565625" y="-2.257290625"/>
<vertex x="-1.724996875" y="-2.15"/>
<vertex x="-1.735565625" y="-2.042709375"/>
<vertex x="-1.766859375" y="-1.939540625"/>
<vertex x="-1.817690625" y="-1.844434375"/>
<vertex x="-1.886090625" y="-1.761090625"/>
<vertex x="-1.969434375" y="-1.692690625"/>
<vertex x="-2.064540625" y="-1.641859375"/>
<vertex x="-2.167709375" y="-1.610565625"/>
<vertex x="-2.2749875" y="-1.6"/>
<vertex x="-2.5250125" y="-1.6"/>
<vertex x="-2.632290625" y="-1.610565625"/>
<vertex x="-2.735459375" y="-1.641859375"/>
<vertex x="-2.830565625" y="-1.692690625"/>
<vertex x="-2.913909375" y="-1.761090625"/>
<vertex x="-2.982309375" y="-1.844434375"/>
<vertex x="-3.033140625" y="-1.939540625"/>
<vertex x="-3.064434375" y="-2.042709375"/>
<vertex x="-3.075003125" y="-2.15"/>
<vertex x="-3.064434375" y="-2.257290625"/>
<vertex x="-3.033140625" y="-2.360459375"/>
<vertex x="-2.982309375" y="-2.455565625"/>
<vertex x="-2.913909375" y="-2.538909375"/>
<vertex x="-2.830565625" y="-2.607309375"/>
<vertex x="-2.735459375" y="-2.658140625"/>
<vertex x="-2.632290625" y="-2.689434375"/>
</polygon>
<polygon width="0.01" layer="1" pour="solid">
<vertex x="2.2749875" y="1.6"/>
<vertex x="2.5250125" y="1.6"/>
<vertex x="2.632290625" y="1.610565625"/>
<vertex x="2.735459375" y="1.641859375"/>
<vertex x="2.830565625" y="1.692690625"/>
<vertex x="2.913909375" y="1.761090625"/>
<vertex x="2.982309375" y="1.844434375"/>
<vertex x="3.033140625" y="1.939540625"/>
<vertex x="3.064434375" y="2.042709375"/>
<vertex x="3.075003125" y="2.15"/>
<vertex x="3.064434375" y="2.257290625"/>
<vertex x="3.033140625" y="2.360459375"/>
<vertex x="2.982309375" y="2.455565625"/>
<vertex x="2.913909375" y="2.538909375"/>
<vertex x="2.830565625" y="2.607309375"/>
<vertex x="2.735459375" y="2.658140625"/>
<vertex x="2.632290625" y="2.689434375"/>
<vertex x="2.5250125" y="2.7"/>
<vertex x="2.2749875" y="2.7"/>
<vertex x="2.167709375" y="2.689434375"/>
<vertex x="2.064540625" y="2.658140625"/>
<vertex x="1.969434375" y="2.607309375"/>
<vertex x="1.886090625" y="2.538909375"/>
<vertex x="1.817690625" y="2.455565625"/>
<vertex x="1.766859375" y="2.360459375"/>
<vertex x="1.735565625" y="2.257290625"/>
<vertex x="1.724996875" y="2.15"/>
<vertex x="1.735565625" y="2.042709375"/>
<vertex x="1.766859375" y="1.939540625"/>
<vertex x="1.817690625" y="1.844434375"/>
<vertex x="1.886090625" y="1.761090625"/>
<vertex x="1.969434375" y="1.692690625"/>
<vertex x="2.064540625" y="1.641859375"/>
<vertex x="2.167709375" y="1.610565625"/>
</polygon>
<polygon width="0.01" layer="1" pour="solid">
<vertex x="2.2749875" y="-2.7"/>
<vertex x="2.5250125" y="-2.7"/>
<vertex x="2.632290625" y="-2.689434375"/>
<vertex x="2.735459375" y="-2.658140625"/>
<vertex x="2.830565625" y="-2.607309375"/>
<vertex x="2.913909375" y="-2.538909375"/>
<vertex x="2.982309375" y="-2.455565625"/>
<vertex x="3.033140625" y="-2.360459375"/>
<vertex x="3.064434375" y="-2.257290625"/>
<vertex x="3.075003125" y="-2.15"/>
<vertex x="3.064434375" y="-2.042709375"/>
<vertex x="3.033140625" y="-1.939540625"/>
<vertex x="2.982309375" y="-1.844434375"/>
<vertex x="2.913909375" y="-1.761090625"/>
<vertex x="2.830565625" y="-1.692690625"/>
<vertex x="2.735459375" y="-1.641859375"/>
<vertex x="2.632290625" y="-1.610565625"/>
<vertex x="2.5250125" y="-1.6"/>
<vertex x="2.2749875" y="-1.6"/>
<vertex x="2.167709375" y="-1.610565625"/>
<vertex x="2.064540625" y="-1.641859375"/>
<vertex x="1.969434375" y="-1.692690625"/>
<vertex x="1.886090625" y="-1.761090625"/>
<vertex x="1.817690625" y="-1.844434375"/>
<vertex x="1.766859375" y="-1.939540625"/>
<vertex x="1.735565625" y="-2.042709375"/>
<vertex x="1.724996875" y="-2.15"/>
<vertex x="1.735565625" y="-2.257290625"/>
<vertex x="1.766859375" y="-2.360459375"/>
<vertex x="1.817690625" y="-2.455565625"/>
<vertex x="1.886090625" y="-2.538909375"/>
<vertex x="1.969434375" y="-2.607309375"/>
<vertex x="2.064540625" y="-2.658140625"/>
<vertex x="2.167709375" y="-2.689434375"/>
</polygon>
<polygon width="0.01" layer="16" pour="solid">
<vertex x="-2.5250125" y="1.6"/>
<vertex x="-2.2749875" y="1.6"/>
<vertex x="-2.167709375" y="1.610565625"/>
<vertex x="-2.064540625" y="1.641859375"/>
<vertex x="-1.969434375" y="1.692690625"/>
<vertex x="-1.886090625" y="1.761090625"/>
<vertex x="-1.817690625" y="1.844434375"/>
<vertex x="-1.766859375" y="1.939540625"/>
<vertex x="-1.735565625" y="2.042709375"/>
<vertex x="-1.724996875" y="2.15"/>
<vertex x="-1.735565625" y="2.257290625"/>
<vertex x="-1.766859375" y="2.360459375"/>
<vertex x="-1.817690625" y="2.455565625"/>
<vertex x="-1.886090625" y="2.538909375"/>
<vertex x="-1.969434375" y="2.607309375"/>
<vertex x="-2.064540625" y="2.658140625"/>
<vertex x="-2.167709375" y="2.689434375"/>
<vertex x="-2.2749875" y="2.7"/>
<vertex x="-2.5250125" y="2.7"/>
<vertex x="-2.632290625" y="2.689434375"/>
<vertex x="-2.735459375" y="2.658140625"/>
<vertex x="-2.830565625" y="2.607309375"/>
<vertex x="-2.913909375" y="2.538909375"/>
<vertex x="-2.982309375" y="2.455565625"/>
<vertex x="-3.033140625" y="2.360459375"/>
<vertex x="-3.064434375" y="2.257290625"/>
<vertex x="-3.075003125" y="2.15"/>
<vertex x="-3.064434375" y="2.042709375"/>
<vertex x="-3.033140625" y="1.939540625"/>
<vertex x="-2.982309375" y="1.844434375"/>
<vertex x="-2.913909375" y="1.761090625"/>
<vertex x="-2.830565625" y="1.692690625"/>
<vertex x="-2.735459375" y="1.641859375"/>
<vertex x="-2.632290625" y="1.610565625"/>
</polygon>
<polygon width="0.01" layer="16" pour="solid">
<vertex x="2.2749875" y="1.6"/>
<vertex x="2.5250125" y="1.6"/>
<vertex x="2.632290625" y="1.610565625"/>
<vertex x="2.735459375" y="1.641859375"/>
<vertex x="2.830565625" y="1.692690625"/>
<vertex x="2.913909375" y="1.761090625"/>
<vertex x="2.982309375" y="1.844434375"/>
<vertex x="3.033140625" y="1.939540625"/>
<vertex x="3.064434375" y="2.042709375"/>
<vertex x="3.075003125" y="2.15"/>
<vertex x="3.064434375" y="2.257290625"/>
<vertex x="3.033140625" y="2.360459375"/>
<vertex x="2.982309375" y="2.455565625"/>
<vertex x="2.913909375" y="2.538909375"/>
<vertex x="2.830565625" y="2.607309375"/>
<vertex x="2.735459375" y="2.658140625"/>
<vertex x="2.632290625" y="2.689434375"/>
<vertex x="2.5250125" y="2.7"/>
<vertex x="2.2749875" y="2.7"/>
<vertex x="2.167709375" y="2.689434375"/>
<vertex x="2.064540625" y="2.658140625"/>
<vertex x="1.969434375" y="2.607309375"/>
<vertex x="1.886090625" y="2.538909375"/>
<vertex x="1.817690625" y="2.455565625"/>
<vertex x="1.766859375" y="2.360459375"/>
<vertex x="1.735565625" y="2.257290625"/>
<vertex x="1.724996875" y="2.15"/>
<vertex x="1.735565625" y="2.042709375"/>
<vertex x="1.766859375" y="1.939540625"/>
<vertex x="1.817690625" y="1.844434375"/>
<vertex x="1.886090625" y="1.761090625"/>
<vertex x="1.969434375" y="1.692690625"/>
<vertex x="2.064540625" y="1.641859375"/>
<vertex x="2.167709375" y="1.610565625"/>
</polygon>
<polygon width="0.01" layer="16" pour="solid">
<vertex x="-2.5250125" y="-2.7"/>
<vertex x="-2.2749875" y="-2.7"/>
<vertex x="-2.167709375" y="-2.689434375"/>
<vertex x="-2.064540625" y="-2.658140625"/>
<vertex x="-1.969434375" y="-2.607309375"/>
<vertex x="-1.886090625" y="-2.538909375"/>
<vertex x="-1.817690625" y="-2.455565625"/>
<vertex x="-1.766859375" y="-2.360459375"/>
<vertex x="-1.735565625" y="-2.257290625"/>
<vertex x="-1.724996875" y="-2.15"/>
<vertex x="-1.735565625" y="-2.042709375"/>
<vertex x="-1.766859375" y="-1.939540625"/>
<vertex x="-1.817690625" y="-1.844434375"/>
<vertex x="-1.886090625" y="-1.761090625"/>
<vertex x="-1.969434375" y="-1.692690625"/>
<vertex x="-2.064540625" y="-1.641859375"/>
<vertex x="-2.167709375" y="-1.610565625"/>
<vertex x="-2.2749875" y="-1.6"/>
<vertex x="-2.5250125" y="-1.6"/>
<vertex x="-2.632290625" y="-1.610565625"/>
<vertex x="-2.735459375" y="-1.641859375"/>
<vertex x="-2.830565625" y="-1.692690625"/>
<vertex x="-2.913909375" y="-1.761090625"/>
<vertex x="-2.982309375" y="-1.844434375"/>
<vertex x="-3.033140625" y="-1.939540625"/>
<vertex x="-3.064434375" y="-2.042709375"/>
<vertex x="-3.075003125" y="-2.15"/>
<vertex x="-3.064434375" y="-2.257290625"/>
<vertex x="-3.033140625" y="-2.360459375"/>
<vertex x="-2.982309375" y="-2.455565625"/>
<vertex x="-2.913909375" y="-2.538909375"/>
<vertex x="-2.830565625" y="-2.607309375"/>
<vertex x="-2.735459375" y="-2.658140625"/>
<vertex x="-2.632290625" y="-2.689434375"/>
</polygon>
<polygon width="0.01" layer="16" pour="solid">
<vertex x="2.2749875" y="-2.7"/>
<vertex x="2.5250125" y="-2.7"/>
<vertex x="2.632290625" y="-2.689434375"/>
<vertex x="2.735459375" y="-2.658140625"/>
<vertex x="2.830565625" y="-2.607309375"/>
<vertex x="2.913909375" y="-2.538909375"/>
<vertex x="2.982309375" y="-2.455565625"/>
<vertex x="3.033140625" y="-2.360459375"/>
<vertex x="3.064434375" y="-2.257290625"/>
<vertex x="3.075003125" y="-2.15"/>
<vertex x="3.064434375" y="-2.042709375"/>
<vertex x="3.033140625" y="-1.939540625"/>
<vertex x="2.982309375" y="-1.844434375"/>
<vertex x="2.913909375" y="-1.761090625"/>
<vertex x="2.830565625" y="-1.692690625"/>
<vertex x="2.735459375" y="-1.641859375"/>
<vertex x="2.632290625" y="-1.610565625"/>
<vertex x="2.5250125" y="-1.6"/>
<vertex x="2.2749875" y="-1.6"/>
<vertex x="2.167709375" y="-1.610565625"/>
<vertex x="2.064540625" y="-1.641859375"/>
<vertex x="1.969434375" y="-1.692690625"/>
<vertex x="1.886090625" y="-1.761090625"/>
<vertex x="1.817690625" y="-1.844434375"/>
<vertex x="1.766859375" y="-1.939540625"/>
<vertex x="1.735565625" y="-2.042709375"/>
<vertex x="1.724996875" y="-2.15"/>
<vertex x="1.735565625" y="-2.257290625"/>
<vertex x="1.766859375" y="-2.360459375"/>
<vertex x="1.817690625" y="-2.455565625"/>
<vertex x="1.886090625" y="-2.538909375"/>
<vertex x="1.969434375" y="-2.607309375"/>
<vertex x="2.064540625" y="-2.658140625"/>
<vertex x="2.167709375" y="-2.689434375"/>
</polygon>
<polygon width="0.01" layer="29" pour="solid">
<vertex x="-2.5250125" y="1.5"/>
<vertex x="-2.2749875" y="1.5"/>
<vertex x="-2.1482" y="1.5124875"/>
<vertex x="-2.026271875" y="1.549471875"/>
<vertex x="-1.913875" y="1.60954375"/>
<vertex x="-1.81538125" y="1.69038125"/>
<vertex x="-1.73454375" y="1.788875"/>
<vertex x="-1.674471875" y="1.901271875"/>
<vertex x="-1.6374875" y="2.0232"/>
<vertex x="-1.624996875" y="2.15"/>
<vertex x="-1.6374875" y="2.2768"/>
<vertex x="-1.674471875" y="2.398728125"/>
<vertex x="-1.73454375" y="2.511125"/>
<vertex x="-1.81538125" y="2.60961875"/>
<vertex x="-1.913875" y="2.69045625"/>
<vertex x="-2.026271875" y="2.750528125"/>
<vertex x="-2.1482" y="2.7875125"/>
<vertex x="-2.2749875" y="2.8"/>
<vertex x="-2.5250125" y="2.8"/>
<vertex x="-2.6518" y="2.7875125"/>
<vertex x="-2.773728125" y="2.750528125"/>
<vertex x="-2.886125" y="2.69045625"/>
<vertex x="-2.98461875" y="2.60961875"/>
<vertex x="-3.06545625" y="2.511125"/>
<vertex x="-3.125528125" y="2.398728125"/>
<vertex x="-3.1625125" y="2.2768"/>
<vertex x="-3.175003125" y="2.15"/>
<vertex x="-3.1625125" y="2.0232"/>
<vertex x="-3.125528125" y="1.901271875"/>
<vertex x="-3.06545625" y="1.788875"/>
<vertex x="-2.98461875" y="1.69038125"/>
<vertex x="-2.886125" y="1.60954375"/>
<vertex x="-2.773728125" y="1.549471875"/>
<vertex x="-2.6518" y="1.5124875"/>
</polygon>
<polygon width="0.01" layer="29" pour="solid">
<vertex x="-2.5250125" y="-2.8"/>
<vertex x="-2.2749875" y="-2.8"/>
<vertex x="-2.1482" y="-2.7875125"/>
<vertex x="-2.026271875" y="-2.750528125"/>
<vertex x="-1.913875" y="-2.69045625"/>
<vertex x="-1.81538125" y="-2.60961875"/>
<vertex x="-1.73454375" y="-2.511125"/>
<vertex x="-1.674471875" y="-2.398728125"/>
<vertex x="-1.6374875" y="-2.2768"/>
<vertex x="-1.624996875" y="-2.15"/>
<vertex x="-1.6374875" y="-2.0232"/>
<vertex x="-1.674471875" y="-1.901271875"/>
<vertex x="-1.73454375" y="-1.788875"/>
<vertex x="-1.81538125" y="-1.69038125"/>
<vertex x="-1.913875" y="-1.60954375"/>
<vertex x="-2.026271875" y="-1.549471875"/>
<vertex x="-2.1482" y="-1.5124875"/>
<vertex x="-2.2749875" y="-1.5"/>
<vertex x="-2.5250125" y="-1.5"/>
<vertex x="-2.6518" y="-1.5124875"/>
<vertex x="-2.773728125" y="-1.549471875"/>
<vertex x="-2.886125" y="-1.60954375"/>
<vertex x="-2.98461875" y="-1.69038125"/>
<vertex x="-3.06545625" y="-1.788875"/>
<vertex x="-3.125528125" y="-1.901271875"/>
<vertex x="-3.1625125" y="-2.0232"/>
<vertex x="-3.175003125" y="-2.15"/>
<vertex x="-3.1625125" y="-2.2768"/>
<vertex x="-3.125528125" y="-2.398728125"/>
<vertex x="-3.06545625" y="-2.511125"/>
<vertex x="-2.98461875" y="-2.60961875"/>
<vertex x="-2.886125" y="-2.69045625"/>
<vertex x="-2.773728125" y="-2.750528125"/>
<vertex x="-2.6518" y="-2.7875125"/>
</polygon>
<polygon width="0.01" layer="29" pour="solid">
<vertex x="2.2749875" y="1.5"/>
<vertex x="2.5250125" y="1.5"/>
<vertex x="2.6518" y="1.5124875"/>
<vertex x="2.773728125" y="1.549471875"/>
<vertex x="2.886125" y="1.60954375"/>
<vertex x="2.98461875" y="1.69038125"/>
<vertex x="3.06545625" y="1.788875"/>
<vertex x="3.125528125" y="1.901271875"/>
<vertex x="3.1625125" y="2.0232"/>
<vertex x="3.175003125" y="2.15"/>
<vertex x="3.1625125" y="2.2768"/>
<vertex x="3.125528125" y="2.398728125"/>
<vertex x="3.06545625" y="2.511125"/>
<vertex x="2.98461875" y="2.60961875"/>
<vertex x="2.886125" y="2.69045625"/>
<vertex x="2.773728125" y="2.750528125"/>
<vertex x="2.6518" y="2.7875125"/>
<vertex x="2.5250125" y="2.8"/>
<vertex x="2.2749875" y="2.8"/>
<vertex x="2.1482" y="2.7875125"/>
<vertex x="2.026271875" y="2.750528125"/>
<vertex x="1.913875" y="2.69045625"/>
<vertex x="1.81538125" y="2.60961875"/>
<vertex x="1.73454375" y="2.511125"/>
<vertex x="1.674471875" y="2.398728125"/>
<vertex x="1.6374875" y="2.2768"/>
<vertex x="1.624996875" y="2.15"/>
<vertex x="1.6374875" y="2.0232"/>
<vertex x="1.674471875" y="1.901271875"/>
<vertex x="1.73454375" y="1.788875"/>
<vertex x="1.81538125" y="1.69038125"/>
<vertex x="1.913875" y="1.60954375"/>
<vertex x="2.026271875" y="1.549471875"/>
<vertex x="2.1482" y="1.5124875"/>
</polygon>
<polygon width="0.01" layer="29" pour="solid">
<vertex x="2.2749875" y="-2.8"/>
<vertex x="2.5250125" y="-2.8"/>
<vertex x="2.6518" y="-2.7875125"/>
<vertex x="2.773728125" y="-2.750528125"/>
<vertex x="2.886125" y="-2.69045625"/>
<vertex x="2.98461875" y="-2.60961875"/>
<vertex x="3.06545625" y="-2.511125"/>
<vertex x="3.125528125" y="-2.398728125"/>
<vertex x="3.1625125" y="-2.2768"/>
<vertex x="3.175003125" y="-2.15"/>
<vertex x="3.1625125" y="-2.0232"/>
<vertex x="3.125528125" y="-1.901271875"/>
<vertex x="3.06545625" y="-1.788875"/>
<vertex x="2.98461875" y="-1.69038125"/>
<vertex x="2.886125" y="-1.60954375"/>
<vertex x="2.773728125" y="-1.549471875"/>
<vertex x="2.6518" y="-1.5124875"/>
<vertex x="2.5250125" y="-1.5"/>
<vertex x="2.2749875" y="-1.5"/>
<vertex x="2.1482" y="-1.5124875"/>
<vertex x="2.026271875" y="-1.549471875"/>
<vertex x="1.913875" y="-1.60954375"/>
<vertex x="1.81538125" y="-1.69038125"/>
<vertex x="1.73454375" y="-1.788875"/>
<vertex x="1.674471875" y="-1.901271875"/>
<vertex x="1.6374875" y="-2.0232"/>
<vertex x="1.624996875" y="-2.15"/>
<vertex x="1.6374875" y="-2.2768"/>
<vertex x="1.674471875" y="-2.398728125"/>
<vertex x="1.73454375" y="-2.511125"/>
<vertex x="1.81538125" y="-2.60961875"/>
<vertex x="1.913875" y="-2.69045625"/>
<vertex x="2.026271875" y="-2.750528125"/>
<vertex x="2.1482" y="-2.7875125"/>
</polygon>
<polygon width="0.01" layer="30" pour="solid">
<vertex x="-2.5250125" y="1.5"/>
<vertex x="-2.2749875" y="1.5"/>
<vertex x="-2.1482" y="1.5124875"/>
<vertex x="-2.026271875" y="1.549471875"/>
<vertex x="-1.913875" y="1.60954375"/>
<vertex x="-1.81538125" y="1.69038125"/>
<vertex x="-1.73454375" y="1.788875"/>
<vertex x="-1.674471875" y="1.901271875"/>
<vertex x="-1.6374875" y="2.0232"/>
<vertex x="-1.624996875" y="2.15"/>
<vertex x="-1.6374875" y="2.2768"/>
<vertex x="-1.674471875" y="2.398728125"/>
<vertex x="-1.73454375" y="2.511125"/>
<vertex x="-1.81538125" y="2.60961875"/>
<vertex x="-1.913875" y="2.69045625"/>
<vertex x="-2.026271875" y="2.750528125"/>
<vertex x="-2.1482" y="2.7875125"/>
<vertex x="-2.2749875" y="2.8"/>
<vertex x="-2.5250125" y="2.8"/>
<vertex x="-2.6518" y="2.7875125"/>
<vertex x="-2.773728125" y="2.750528125"/>
<vertex x="-2.886125" y="2.69045625"/>
<vertex x="-2.98461875" y="2.60961875"/>
<vertex x="-3.06545625" y="2.511125"/>
<vertex x="-3.125528125" y="2.398728125"/>
<vertex x="-3.1625125" y="2.2768"/>
<vertex x="-3.175003125" y="2.15"/>
<vertex x="-3.1625125" y="2.0232"/>
<vertex x="-3.125528125" y="1.901271875"/>
<vertex x="-3.06545625" y="1.788875"/>
<vertex x="-2.98461875" y="1.69038125"/>
<vertex x="-2.886125" y="1.60954375"/>
<vertex x="-2.773728125" y="1.549471875"/>
<vertex x="-2.6518" y="1.5124875"/>
</polygon>
<polygon width="0.01" layer="30" pour="solid">
<vertex x="2.2749875" y="1.5"/>
<vertex x="2.5250125" y="1.5"/>
<vertex x="2.6518" y="1.5124875"/>
<vertex x="2.773728125" y="1.549471875"/>
<vertex x="2.886125" y="1.60954375"/>
<vertex x="2.98461875" y="1.69038125"/>
<vertex x="3.06545625" y="1.788875"/>
<vertex x="3.125528125" y="1.901271875"/>
<vertex x="3.1625125" y="2.0232"/>
<vertex x="3.175003125" y="2.15"/>
<vertex x="3.1625125" y="2.2768"/>
<vertex x="3.125528125" y="2.398728125"/>
<vertex x="3.06545625" y="2.511125"/>
<vertex x="2.98461875" y="2.60961875"/>
<vertex x="2.886125" y="2.69045625"/>
<vertex x="2.773728125" y="2.750528125"/>
<vertex x="2.6518" y="2.7875125"/>
<vertex x="2.5250125" y="2.8"/>
<vertex x="2.2749875" y="2.8"/>
<vertex x="2.1482" y="2.7875125"/>
<vertex x="2.026271875" y="2.750528125"/>
<vertex x="1.913875" y="2.69045625"/>
<vertex x="1.81538125" y="2.60961875"/>
<vertex x="1.73454375" y="2.511125"/>
<vertex x="1.674471875" y="2.398728125"/>
<vertex x="1.6374875" y="2.2768"/>
<vertex x="1.624996875" y="2.15"/>
<vertex x="1.6374875" y="2.0232"/>
<vertex x="1.674471875" y="1.901271875"/>
<vertex x="1.73454375" y="1.788875"/>
<vertex x="1.81538125" y="1.69038125"/>
<vertex x="1.913875" y="1.60954375"/>
<vertex x="2.026271875" y="1.549471875"/>
<vertex x="2.1482" y="1.5124875"/>
</polygon>
<polygon width="0.01" layer="30" pour="solid">
<vertex x="-2.5250125" y="-2.8"/>
<vertex x="-2.2749875" y="-2.8"/>
<vertex x="-2.1482" y="-2.7875125"/>
<vertex x="-2.026271875" y="-2.750528125"/>
<vertex x="-1.913875" y="-2.69045625"/>
<vertex x="-1.81538125" y="-2.60961875"/>
<vertex x="-1.73454375" y="-2.511125"/>
<vertex x="-1.674471875" y="-2.398728125"/>
<vertex x="-1.6374875" y="-2.2768"/>
<vertex x="-1.624996875" y="-2.15"/>
<vertex x="-1.6374875" y="-2.0232"/>
<vertex x="-1.674471875" y="-1.901271875"/>
<vertex x="-1.73454375" y="-1.788875"/>
<vertex x="-1.81538125" y="-1.69038125"/>
<vertex x="-1.913875" y="-1.60954375"/>
<vertex x="-2.026271875" y="-1.549471875"/>
<vertex x="-2.1482" y="-1.5124875"/>
<vertex x="-2.2749875" y="-1.5"/>
<vertex x="-2.5250125" y="-1.5"/>
<vertex x="-2.6518" y="-1.5124875"/>
<vertex x="-2.773728125" y="-1.549471875"/>
<vertex x="-2.886125" y="-1.60954375"/>
<vertex x="-2.98461875" y="-1.69038125"/>
<vertex x="-3.06545625" y="-1.788875"/>
<vertex x="-3.125528125" y="-1.901271875"/>
<vertex x="-3.1625125" y="-2.0232"/>
<vertex x="-3.175003125" y="-2.15"/>
<vertex x="-3.1625125" y="-2.2768"/>
<vertex x="-3.125528125" y="-2.398728125"/>
<vertex x="-3.06545625" y="-2.511125"/>
<vertex x="-2.98461875" y="-2.60961875"/>
<vertex x="-2.886125" y="-2.69045625"/>
<vertex x="-2.773728125" y="-2.750528125"/>
<vertex x="-2.6518" y="-2.7875125"/>
</polygon>
<polygon width="0.01" layer="30" pour="solid">
<vertex x="2.2749875" y="-2.8"/>
<vertex x="2.5250125" y="-2.8"/>
<vertex x="2.6518" y="-2.7875125"/>
<vertex x="2.773728125" y="-2.750528125"/>
<vertex x="2.886125" y="-2.69045625"/>
<vertex x="2.98461875" y="-2.60961875"/>
<vertex x="3.06545625" y="-2.511125"/>
<vertex x="3.125528125" y="-2.398728125"/>
<vertex x="3.1625125" y="-2.2768"/>
<vertex x="3.175003125" y="-2.15"/>
<vertex x="3.1625125" y="-2.0232"/>
<vertex x="3.125528125" y="-1.901271875"/>
<vertex x="3.06545625" y="-1.788875"/>
<vertex x="2.98461875" y="-1.69038125"/>
<vertex x="2.886125" y="-1.60954375"/>
<vertex x="2.773728125" y="-1.549471875"/>
<vertex x="2.6518" y="-1.5124875"/>
<vertex x="2.5250125" y="-1.5"/>
<vertex x="2.2749875" y="-1.5"/>
<vertex x="2.1482" y="-1.5124875"/>
<vertex x="2.026271875" y="-1.549471875"/>
<vertex x="1.913875" y="-1.60954375"/>
<vertex x="1.81538125" y="-1.69038125"/>
<vertex x="1.73454375" y="-1.788875"/>
<vertex x="1.674471875" y="-1.901271875"/>
<vertex x="1.6374875" y="-2.0232"/>
<vertex x="1.624996875" y="-2.15"/>
<vertex x="1.6374875" y="-2.2768"/>
<vertex x="1.674471875" y="-2.398728125"/>
<vertex x="1.73454375" y="-2.511125"/>
<vertex x="1.81538125" y="-2.60961875"/>
<vertex x="1.913875" y="-2.69045625"/>
<vertex x="2.026271875" y="-2.750528125"/>
<vertex x="2.1482" y="-2.7875125"/>
</polygon>
<hole x="-3.75" y="0" drill="0.52"/>
<hole x="3.75" y="0" drill="0.52"/>
<pad name="S1" x="-2.4" y="2.15" drill="0.6" diameter="1.1" stop="no"/>
<pad name="S2" x="-2.4" y="-2.15" drill="0.6" diameter="1.1" stop="no"/>
<pad name="S3" x="2.4" y="2.15" drill="0.6" diameter="1.1" stop="no"/>
<pad name="S4" x="2.4" y="-2.15" drill="0.6" diameter="1.1" stop="no"/>
<smd name="A1" x="-2.75" y="0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="A12" x="2.75" y="0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="A6" x="-0.25" y="0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="A7" x="0.25" y="0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="A5" x="-0.75" y="0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="A4" x="-1.25" y="0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="A8" x="0.75" y="0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="A9" x="1.25" y="0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="B12" x="-2.75" y="-0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="B1" x="2.75" y="-0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="B7" x="-0.25" y="-0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="B6" x="0.25" y="-0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="B8" x="-0.75" y="-0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="B9" x="-1.25" y="-0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="B5" x="0.75" y="-0.865" dx="0.3" dy="0.87" layer="1"/>
<smd name="B4" x="1.25" y="-0.865" dx="0.3" dy="0.87" layer="1"/>
</package>
<package name="XCVR_ESP32S3WROOM1N8R8" library_version="27">
<text x="-9.75" y="13.5" size="1.27" layer="25">&gt;NAME</text>
<text x="-9.75" y="-15" size="1.27" layer="27">&gt;VALUE</text>
<wire x1="-9" y1="12.75" x2="9" y2="12.75" width="0.127" layer="51"/>
<wire x1="9" y1="12.75" x2="9" y2="6.75" width="0.127" layer="51"/>
<wire x1="9" y1="6.75" x2="9" y2="-12.75" width="0.127" layer="51"/>
<wire x1="9" y1="-12.75" x2="-9" y2="-12.75" width="0.127" layer="51"/>
<wire x1="-9" y1="-12.75" x2="-9" y2="6.75" width="0.127" layer="51"/>
<wire x1="-9" y1="6.75" x2="-9" y2="12.75" width="0.127" layer="51"/>
<wire x1="-9" y1="6.75" x2="9" y2="6.75" width="0.127" layer="51"/>
<text x="-4.5" y="9.5" size="1.27" layer="51">ANTENNA</text>
<wire x1="-9.75" y1="-13.5" x2="-9.75" y2="13" width="0.05" layer="39"/>
<wire x1="-9.75" y1="13" x2="9.75" y2="13" width="0.05" layer="39"/>
<wire x1="9.75" y1="13" x2="9.75" y2="-13.5" width="0.05" layer="39"/>
<wire x1="-9.75" y1="-13.5" x2="9.75" y2="-13.5" width="0.05" layer="39"/>
<circle x="-10.2" y="5.26" radius="0.1" width="0.2" layer="51"/>
<wire x1="-9" y1="12.75" x2="9" y2="12.75" width="0.127" layer="21"/>
<wire x1="9" y1="12.75" x2="9" y2="6.03" width="0.127" layer="21"/>
<wire x1="-9" y1="6.03" x2="-9" y2="12.75" width="0.127" layer="21"/>
<circle x="-10.2" y="5.26" radius="0.1" width="0.2" layer="21"/>
<rectangle x1="-9" y1="6.75" x2="9" y2="12.75" layer="41"/>
<rectangle x1="-9" y1="6.75" x2="9" y2="12.75" layer="42"/>
<rectangle x1="-9" y1="6.75" x2="9" y2="12.75" layer="43"/>
<wire x1="-9" y1="-12.02" x2="-9" y2="-12.75" width="0.127" layer="21"/>
<wire x1="-9" y1="-12.75" x2="-7.755" y2="-12.75" width="0.127" layer="21"/>
<wire x1="9" y1="-12.02" x2="9" y2="-12.75" width="0.127" layer="21"/>
<wire x1="9" y1="-12.75" x2="7.755" y2="-12.75" width="0.127" layer="21"/>
<smd name="41_1" x="-1.5" y="-2.46" dx="0.9" dy="0.9" layer="1"/>
<smd name="1" x="-8.75" y="5.26" dx="1.5" dy="0.9" layer="1"/>
<smd name="41_2" x="-2.9" y="-2.46" dx="0.9" dy="0.9" layer="1"/>
<smd name="41_3" x="-0.1" y="-2.46" dx="0.9" dy="0.9" layer="1"/>
<smd name="41_4" x="-2.9" y="-3.86" dx="0.9" dy="0.9" layer="1"/>
<smd name="41_5" x="-1.5" y="-3.86" dx="0.9" dy="0.9" layer="1"/>
<smd name="41_6" x="-0.1" y="-3.86" dx="0.9" dy="0.9" layer="1"/>
<smd name="41_7" x="-2.9" y="-1.06" dx="0.9" dy="0.9" layer="1"/>
<smd name="41_8" x="-1.5" y="-1.06" dx="0.9" dy="0.9" layer="1"/>
<smd name="41_9" x="-0.1" y="-1.06" dx="0.9" dy="0.9" layer="1"/>
<pad name="41_10" x="-1.5" y="-1.76" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_11" x="-2.9" y="-1.76" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_12" x="-0.1" y="-1.76" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_13" x="-2.9" y="-3.16" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_14" x="-1.5" y="-3.16" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_15" x="-0.1" y="-3.16" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_16" x="-2.2" y="-1.06" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_17" x="-0.8" y="-1.06" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_18" x="-2.2" y="-2.46" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_19" x="-0.8" y="-2.46" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_20" x="-2.2" y="-3.86" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<pad name="41_21" x="-0.8" y="-3.86" drill="0.2" diameter="0.4" stop="no" thermals="no"/>
<smd name="2" x="-8.75" y="3.99" dx="1.5" dy="0.9" layer="1"/>
<smd name="3" x="-8.75" y="2.72" dx="1.5" dy="0.9" layer="1"/>
<smd name="4" x="-8.75" y="1.45" dx="1.5" dy="0.9" layer="1"/>
<smd name="5" x="-8.75" y="0.18" dx="1.5" dy="0.9" layer="1"/>
<smd name="6" x="-8.75" y="-1.09" dx="1.5" dy="0.9" layer="1"/>
<smd name="7" x="-8.75" y="-2.36" dx="1.5" dy="0.9" layer="1"/>
<smd name="8" x="-8.75" y="-3.63" dx="1.5" dy="0.9" layer="1"/>
<smd name="9" x="-8.75" y="-4.9" dx="1.5" dy="0.9" layer="1"/>
<smd name="10" x="-8.75" y="-6.17" dx="1.5" dy="0.9" layer="1"/>
<smd name="11" x="-8.75" y="-7.44" dx="1.5" dy="0.9" layer="1"/>
<smd name="12" x="-8.75" y="-8.71" dx="1.5" dy="0.9" layer="1"/>
<smd name="13" x="-8.75" y="-9.98" dx="1.5" dy="0.9" layer="1"/>
<smd name="14" x="-8.75" y="-11.25" dx="1.5" dy="0.9" layer="1"/>
<smd name="15" x="-6.985" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="27" x="8.75" y="-11.25" dx="1.5" dy="0.9" layer="1"/>
<smd name="28" x="8.75" y="-9.98" dx="1.5" dy="0.9" layer="1"/>
<smd name="29" x="8.75" y="-8.71" dx="1.5" dy="0.9" layer="1"/>
<smd name="30" x="8.75" y="-7.44" dx="1.5" dy="0.9" layer="1"/>
<smd name="31" x="8.75" y="-6.17" dx="1.5" dy="0.9" layer="1"/>
<smd name="32" x="8.75" y="-4.9" dx="1.5" dy="0.9" layer="1"/>
<smd name="33" x="8.75" y="-3.63" dx="1.5" dy="0.9" layer="1"/>
<smd name="34" x="8.75" y="-2.36" dx="1.5" dy="0.9" layer="1"/>
<smd name="35" x="8.75" y="-1.09" dx="1.5" dy="0.9" layer="1"/>
<smd name="36" x="8.75" y="0.18" dx="1.5" dy="0.9" layer="1"/>
<smd name="37" x="8.75" y="1.45" dx="1.5" dy="0.9" layer="1"/>
<smd name="38" x="8.75" y="2.72" dx="1.5" dy="0.9" layer="1"/>
<smd name="39" x="8.75" y="3.99" dx="1.5" dy="0.9" layer="1"/>
<smd name="40" x="8.75" y="5.26" dx="1.5" dy="0.9" layer="1"/>
<smd name="16" x="-5.715" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="17" x="-4.445" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="18" x="-3.175" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="19" x="-1.905" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="20" x="-0.635" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="21" x="0.635" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="22" x="1.905" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="23" x="3.175" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="24" x="4.445" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="25" x="5.715" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
<smd name="26" x="6.985" y="-12.5" dx="0.9" dy="1.5" layer="1"/>
</package>
<package name="DIOM1006X40N" library_version="26">
<wire x1="-0.4" y1="0.3" x2="0.4" y2="0.3" width="0.127" layer="51"/>
<wire x1="0.4" y1="0.3" x2="0.4" y2="-0.3" width="0.127" layer="51"/>
<wire x1="0.4" y1="-0.3" x2="-0.4" y2="-0.3" width="0.127" layer="51"/>
<wire x1="-0.4" y1="-0.3" x2="-0.4" y2="0.3" width="0.127" layer="51"/>
<wire x1="-1.3" y1="0.55" x2="-1.3" y2="-0.55" width="0.05" layer="39"/>
<wire x1="-1.3" y1="-0.55" x2="1.3" y2="-0.55" width="0.05" layer="39"/>
<wire x1="1.3" y1="-0.55" x2="1.3" y2="0.55" width="0.05" layer="39"/>
<wire x1="1.3" y1="0.55" x2="-1.3" y2="0.55" width="0.05" layer="39"/>
<wire x1="-0.4" y1="0.415" x2="0.4" y2="0.415" width="0.127" layer="21"/>
<wire x1="0.4" y1="-0.415" x2="-0.4" y2="-0.415" width="0.127" layer="21"/>
<circle x="-1.651" y="0" radius="0.1" width="0.2" layer="21"/>
<circle x="-1.651" y="0" radius="0.1" width="0.2" layer="51"/>
<text x="-1.05" y="1.4" size="0.8" layer="25">&gt;NAME</text>
<text x="-1.05" y="-1.4" size="0.8" layer="27" align="top-left">&gt;VALUE</text>
<smd name="C" x="-0.58" y="0" dx="0.94" dy="0.2" layer="1"/>
<smd name="A" x="0.58" y="0" dx="0.94" dy="0.2" layer="1"/>
</package>
<package name="SOD3715X145N" library_version="26">
<wire x1="-1.425" y1="0.85" x2="1.425" y2="0.85" width="0.127" layer="51"/>
<wire x1="1.425" y1="0.85" x2="1.425" y2="-0.85" width="0.127" layer="51"/>
<wire x1="1.425" y1="-0.85" x2="-1.425" y2="-0.85" width="0.127" layer="51"/>
<wire x1="-1.425" y1="-0.85" x2="-1.425" y2="0.85" width="0.127" layer="51"/>
<wire x1="1.425" y1="-0.85" x2="-1.425" y2="-0.85" width="0.127" layer="21"/>
<wire x1="-1.425" y1="0.85" x2="1.425" y2="0.85" width="0.127" layer="21"/>
<wire x1="-2.535" y1="1.1" x2="2.535" y2="1.1" width="0.05" layer="39"/>
<wire x1="2.535" y1="1.1" x2="2.535" y2="-1.1" width="0.05" layer="39"/>
<wire x1="2.535" y1="-1.1" x2="-2.535" y2="-1.1" width="0.05" layer="39"/>
<wire x1="-2.535" y1="-1.1" x2="-2.535" y2="1.1" width="0.05" layer="39"/>
<text x="-2.50416875" y="1.252090625" size="0.610615625" layer="25">&gt;NAME</text>
<text x="-2.501309375" y="-1.75091875" size="0.60991875" layer="27">&gt;VALUE</text>
<circle x="-3" y="0" radius="0.1" width="0.2" layer="51"/>
<circle x="-3" y="0" radius="0.1" width="0.2" layer="21"/>
<smd name="C" x="-1.68" y="0" dx="1.21" dy="0.73" layer="1"/>
<smd name="A" x="1.68" y="0" dx="1.21" dy="0.73" layer="1"/>
</package>
<package name="SOT95P285X140-5N" library_version="26">
<wire x1="-0.85" y1="1.55" x2="0.85" y2="1.55" width="0.127" layer="51"/>
<wire x1="0.85" y1="1.55" x2="0.85" y2="-1.55" width="0.127" layer="51"/>
<wire x1="0.85" y1="-1.55" x2="-0.85" y2="-1.55" width="0.127" layer="51"/>
<wire x1="-0.85" y1="-1.55" x2="-0.85" y2="1.55" width="0.127" layer="51"/>
<wire x1="0.85" y1="1.55" x2="-0.85" y2="1.55" width="0.127" layer="21"/>
<wire x1="0.85" y1="-1.55" x2="-0.85" y2="-1.55" width="0.127" layer="21"/>
<wire x1="-0.85" y1="-1.55" x2="-0.85" y2="-1.45" width="0.127" layer="21"/>
<wire x1="0.85" y1="-1.55" x2="0.85" y2="-1.45" width="0.127" layer="21"/>
<wire x1="0.85" y1="1.55" x2="0.85" y2="1.45" width="0.127" layer="21"/>
<wire x1="-0.85" y1="1.55" x2="-0.85" y2="1.45" width="0.127" layer="21"/>
<wire x1="1.1" y1="1.8" x2="-1.1" y2="1.8" width="0.05" layer="39"/>
<wire x1="-1.1" y1="1.8" x2="-1.1" y2="1.5" width="0.05" layer="39"/>
<wire x1="-1.1" y1="1.5" x2="-2.11" y2="1.5" width="0.05" layer="39"/>
<wire x1="-2.11" y1="1.5" x2="-2.11" y2="-1.5" width="0.05" layer="39"/>
<wire x1="-2.11" y1="-1.5" x2="-1.1" y2="-1.5" width="0.05" layer="39"/>
<wire x1="-1.1" y1="-1.5" x2="-1.1" y2="-1.8" width="0.05" layer="39"/>
<wire x1="-1.1" y1="-1.8" x2="1.1" y2="-1.8" width="0.05" layer="39"/>
<wire x1="1.1" y1="-1.8" x2="1.1" y2="-1.5" width="0.05" layer="39"/>
<wire x1="1.1" y1="-1.5" x2="2.11" y2="-1.5" width="0.05" layer="39"/>
<wire x1="2.11" y1="-1.5" x2="2.11" y2="1.5" width="0.05" layer="39"/>
<wire x1="2.11" y1="1.5" x2="1.1" y2="1.5" width="0.05" layer="39"/>
<wire x1="1.1" y1="1.5" x2="1.1" y2="1.8" width="0.05" layer="39"/>
<circle x="-2.469" y="0.95" radius="0.1" width="0.2" layer="21"/>
<text x="-1.88393125" y="2.02061875" size="1.019340625" layer="25">&gt;NAME</text>
<text x="-2.181440625" y="-2.9625" size="1.0179" layer="27">&gt;VALUE</text>
<circle x="-0.469" y="0.95" radius="0.1" width="0.2" layer="51"/>
<smd name="1" x="-1.185" y="0.95" dx="1.35" dy="0.6" layer="1" roundness="15"/>
<smd name="2" x="-1.185" y="0" dx="1.35" dy="0.6" layer="1" roundness="15"/>
<smd name="3" x="-1.185" y="-0.95" dx="1.35" dy="0.6" layer="1" roundness="15"/>
<smd name="4" x="1.185" y="-0.95" dx="1.35" dy="0.6" layer="1" roundness="15"/>
<smd name="5" x="1.185" y="0.95" dx="1.35" dy="0.6" layer="1" roundness="15"/>
</package>
<package name="BEADC1608X95N" library_version="26">
<text x="-1.49" y="-0.82" size="0.5" layer="27" align="top-left">&gt;VALUE</text>
<text x="-1.49" y="0.82" size="0.5" layer="25">&gt;NAME</text>
<wire x1="0.88" y1="-0.48" x2="-0.88" y2="-0.48" width="0.127" layer="51"/>
<wire x1="0.88" y1="0.48" x2="-0.88" y2="0.48" width="0.127" layer="51"/>
<wire x1="0.88" y1="-0.48" x2="0.88" y2="0.48" width="0.127" layer="51"/>
<wire x1="-0.88" y1="-0.48" x2="-0.88" y2="0.48" width="0.127" layer="51"/>
<wire x1="-1.485" y1="-0.735" x2="1.485" y2="-0.735" width="0.05" layer="39"/>
<wire x1="-1.485" y1="0.735" x2="1.485" y2="0.735" width="0.05" layer="39"/>
<wire x1="-1.485" y1="-0.735" x2="-1.485" y2="0.735" width="0.05" layer="39"/>
<wire x1="1.485" y1="-0.735" x2="1.485" y2="0.735" width="0.05" layer="39"/>
<smd name="1" x="-0.735" y="0" dx="1" dy="0.97" layer="1"/>
<smd name="2" x="0.735" y="0" dx="1" dy="0.97" layer="1"/>
</package>
</packages>
<symbols>
<symbol name="MAX98357AETE+T" library_version="2">
<wire x1="-12.7" y1="15.24" x2="12.7" y2="15.24" width="0.41" layer="94"/>
<wire x1="12.7" y1="15.24" x2="12.7" y2="-15.24" width="0.41" layer="94"/>
<wire x1="12.7" y1="-15.24" x2="-12.7" y2="-15.24" width="0.41" layer="94"/>
<wire x1="-12.7" y1="-15.24" x2="-12.7" y2="15.24" width="0.41" layer="94"/>
<text x="-12.7" y="16.24" size="2.0828" layer="95" ratio="10" rot="SR0">&gt;NAME</text>
<text x="-12.7" y="-19.24" size="2.0828" layer="96" ratio="10" rot="SR0">&gt;VALUE</text>
<pin name="BCLK" x="-17.78" y="7.62" length="middle" direction="in" function="clk"/>
<pin name="DIN" x="-17.78" y="5.08" length="middle" direction="in"/>
<pin name="GAIN_SLOT" x="-17.78" y="2.54" length="middle" direction="in"/>
<pin name="LRCLK" x="-17.78" y="0" length="middle" direction="in" function="clk"/>
<pin name="SD_MODE" x="-17.78" y="-2.54" length="middle" direction="in"/>
<pin name="VDD" x="17.78" y="12.7" length="middle" direction="pwr" rot="R180"/>
<pin name="OUTN" x="17.78" y="7.62" length="middle" direction="out" rot="R180"/>
<pin name="OUTP" x="17.78" y="5.08" length="middle" direction="out" rot="R180"/>
<pin name="EP" x="17.78" y="-10.16" length="middle" direction="pwr" rot="R180"/>
<pin name="GND" x="17.78" y="-12.7" length="middle" direction="pwr" rot="R180"/>
</symbol>
<symbol name="CONN_002P_000C_1" library_version="11">
<pin name="1" x="0" y="0" visible="pad" length="middle" direction="pas"/>
<pin name="2" x="0" y="-2.54" visible="pad" length="middle" direction="pas"/>
<wire x1="10.16" y1="0" x2="5.08" y2="0" width="0.1524" layer="94"/>
<wire x1="10.16" y1="-2.54" x2="5.08" y2="-2.54" width="0.1524" layer="94"/>
<wire x1="10.16" y1="0" x2="8.89" y2="0.8467" width="0.1524" layer="94"/>
<wire x1="10.16" y1="-2.54" x2="8.89" y2="-1.6933" width="0.1524" layer="94"/>
<wire x1="10.16" y1="0" x2="8.89" y2="-0.8467" width="0.1524" layer="94"/>
<wire x1="10.16" y1="-2.54" x2="8.89" y2="-3.3867" width="0.1524" layer="94"/>
<wire x1="5.08" y1="2.54" x2="5.08" y2="-5.08" width="0.1524" layer="94"/>
<wire x1="5.08" y1="-5.08" x2="12.7" y2="-5.08" width="0.1524" layer="94"/>
<wire x1="12.7" y1="-5.08" x2="12.7" y2="2.54" width="0.1524" layer="94"/>
<wire x1="12.7" y1="2.54" x2="5.08" y2="2.54" width="0.1524" layer="94"/>
<text x="4.1646" y="5.3086" size="2.083" layer="95" ratio="6">&gt;Name</text>
</symbol>
<symbol name="KMR221GLFS" library_version="14">
<wire x1="-2.54" y1="0" x2="2.54" y2="1.27" width="0.254" layer="94"/>
<circle x="2.54" y="0" radius="0.127" width="0.254" layer="94"/>
<circle x="-2.54" y="0" radius="0.127" width="0.254" layer="94"/>
<wire x1="2.54" y1="-2.54" x2="2.54" y2="-3.302" width="0.254" layer="94"/>
<wire x1="2.54" y1="-3.302" x2="2.032" y2="-3.302" width="0.254" layer="94"/>
<wire x1="2.54" y1="-3.302" x2="3.048" y2="-3.302" width="0.254" layer="94"/>
<wire x1="2.286" y1="-3.81" x2="2.794" y2="-3.81" width="0.254" layer="94"/>
<text x="-2.54008125" y="2.28606875" size="1.270040625" layer="95">&gt;NAME</text>
<text x="-2.79733125" y="-6.35756875" size="1.271509375" layer="96">&gt;VALUE</text>
<circle x="2.54" y="1.27" radius="0.127" width="0.254" layer="94"/>
<pin name="1" x="-7.62" y="0" visible="pad" length="middle" direction="pas"/>
<pin name="3" x="7.62" y="0" visible="pad" length="middle" direction="pas" rot="R180"/>
<pin name="5" x="7.62" y="-2.54" visible="pad" length="middle" direction="pas" rot="R180"/>
</symbol>
<symbol name="XL-5050RGBC-WS2812B" library_version="19">
<text x="-10.16" y="8.382" size="1.778" layer="95">&gt;NAME</text>
<text x="-10.16" y="-10.16" size="1.778" layer="96">&gt;VALUE</text>
<wire x1="10.16" y1="7.62" x2="-10.16" y2="7.62" width="0.254" layer="94"/>
<wire x1="-10.16" y1="7.62" x2="-10.16" y2="-7.62" width="0.254" layer="94"/>
<wire x1="-10.16" y1="-7.62" x2="10.16" y2="-7.62" width="0.254" layer="94"/>
<wire x1="10.16" y1="-7.62" x2="10.16" y2="7.62" width="0.254" layer="94"/>
<pin name="VDD" x="15.24" y="5.08" length="middle" direction="pwr" rot="R180"/>
<pin name="DOU" x="15.24" y="0" length="middle" direction="out" rot="R180"/>
<pin name="GND" x="15.24" y="-5.08" length="middle" direction="pwr" rot="R180"/>
<pin name="DIN" x="-15.24" y="0" length="middle" direction="in"/>
</symbol>
<symbol name="CAPH" library_version="20">
<pin name="2" x="7.62" y="0" visible="off" length="short" direction="pas" swaplevel="1" rot="R180"/>
<pin name="1" x="0" y="0" visible="off" length="short" direction="pas" swaplevel="1"/>
<wire x1="3.4798" y1="-1.905" x2="3.4798" y2="1.905" width="0.2032" layer="94"/>
<wire x1="4.1148" y1="-1.905" x2="4.1148" y2="1.905" width="0.2032" layer="94"/>
<wire x1="4.1148" y1="0" x2="5.08" y2="0" width="0.2032" layer="94"/>
<wire x1="2.54" y1="0" x2="3.4798" y2="0" width="0.2032" layer="94"/>
<wire x1="1.27" y1="1.27" x2="1.27" y2="0.635" width="0.1524" layer="94"/>
<wire x1="0.9525" y1="0.9525" x2="1.5875" y2="0.9525" width="0.1524" layer="94"/>
<text x="-5.1531" y="-5.5499" size="3.48" layer="96" ratio="10">&gt;Value</text>
<text x="-4.0848" y="2.0701" size="3.48" layer="95" ratio="10">&gt;Name</text>
</symbol>
<symbol name="ICS-43432" library_version="23">
<wire x1="10.16" y1="15.24" x2="10.16" y2="-12.7" width="0.254" layer="94"/>
<wire x1="10.16" y1="-12.7" x2="-10.16" y2="-12.7" width="0.254" layer="94"/>
<wire x1="-10.16" y1="-12.7" x2="-10.16" y2="15.24" width="0.254" layer="94"/>
<wire x1="-10.16" y1="15.24" x2="10.16" y2="15.24" width="0.254" layer="94"/>
<text x="-10.1999" y="15.8099" size="1.78498125" layer="95">&gt;NAME</text>
<text x="-10.2029" y="-15.3044" size="1.78551875" layer="96">&gt;VALUE</text>
<pin name="LR" x="-15.24" y="7.62" length="middle" direction="in"/>
<pin name="CONFIG" x="-15.24" y="5.08" length="middle" direction="in"/>
<pin name="VDD" x="15.24" y="12.7" length="middle" direction="pwr" rot="R180"/>
<pin name="GND" x="15.24" y="-10.16" length="middle" direction="pwr" rot="R180"/>
<pin name="WS" x="-15.24" y="-5.08" length="middle" direction="in"/>
<pin name="SCK" x="-15.24" y="0" length="middle" direction="in" function="clk"/>
<pin name="SD" x="-15.24" y="-2.54" length="middle" direction="out"/>
</symbol>
<symbol name="USB4120-03-C_REVA6" library_version="25">
<wire x1="-12.7" y1="15.24" x2="12.7" y2="15.24" width="0.254" layer="94"/>
<wire x1="12.7" y1="15.24" x2="12.7" y2="-17.78" width="0.254" layer="94"/>
<wire x1="12.7" y1="-17.78" x2="-12.7" y2="-17.78" width="0.254" layer="94"/>
<wire x1="-12.7" y1="-17.78" x2="-12.7" y2="15.24" width="0.254" layer="94"/>
<text x="-12.7" y="16.002" size="1.778" layer="95">&gt;NAME</text>
<text x="-12.7" y="-18.542" size="1.778" layer="96" rot="MR180">&gt;VALUE</text>
<pin name="GND_A" x="-17.78" y="-10.16" length="middle" direction="pwr"/>
<pin name="VBUS_A" x="-17.78" y="12.7" length="middle" direction="pwr"/>
<pin name="D1+" x="-17.78" y="2.54" length="middle"/>
<pin name="CC1" x="-17.78" y="5.08" length="middle"/>
<pin name="SBU1" x="-17.78" y="-2.54" length="middle"/>
<pin name="D1-" x="-17.78" y="0" length="middle"/>
<pin name="SHIELD" x="-17.78" y="-15.24" length="middle" direction="pas"/>
<pin name="GND_B" x="17.78" y="-10.16" length="middle" direction="pwr" rot="R180"/>
<pin name="VBUS_B" x="17.78" y="12.7" length="middle" direction="pwr" rot="R180"/>
<pin name="D2+" x="17.78" y="0" length="middle" rot="R180"/>
<pin name="CC2" x="17.78" y="-2.54" length="middle" rot="R180"/>
<pin name="SBU2" x="17.78" y="5.08" length="middle" rot="R180"/>
<pin name="D2-" x="17.78" y="2.54" length="middle" rot="R180"/>
</symbol>
<symbol name="ESP32-S3-WROOM-1-N8R8" library_version="26">
<wire x1="-10.16" y1="33.02" x2="10.16" y2="33.02" width="0.254" layer="94"/>
<wire x1="10.16" y1="33.02" x2="10.16" y2="-33.02" width="0.254" layer="94"/>
<wire x1="10.16" y1="-33.02" x2="-10.16" y2="-33.02" width="0.254" layer="94"/>
<wire x1="-10.16" y1="-33.02" x2="-10.16" y2="33.02" width="0.254" layer="94"/>
<text x="-10.16" y="34.1122" size="1.778" layer="95">&gt;NAME</text>
<text x="-10.16" y="-35.56" size="1.778" layer="96">&gt;VALUE</text>
<pin name="GND" x="15.24" y="-30.48" length="middle" direction="pwr" rot="R180"/>
<pin name="3V3" x="15.24" y="30.48" length="middle" direction="pwr" rot="R180"/>
<pin name="EN" x="-15.24" y="27.94" length="middle" direction="in"/>
<pin name="IO35" x="15.24" y="2.54" length="middle" rot="R180"/>
<pin name="IO41" x="15.24" y="-12.7" length="middle" rot="R180"/>
<pin name="IO39" x="15.24" y="-7.62" length="middle" rot="R180"/>
<pin name="IO40" x="15.24" y="-10.16" length="middle" rot="R180"/>
<pin name="IO14" x="-15.24" y="-20.32" length="middle"/>
<pin name="IO12" x="-15.24" y="-15.24" length="middle"/>
<pin name="IO13" x="-15.24" y="-17.78" length="middle"/>
<pin name="IO15" x="-15.24" y="-22.86" length="middle"/>
<pin name="IO2" x="-15.24" y="10.16" length="middle"/>
<pin name="IO0" x="-15.24" y="15.24" length="middle"/>
<pin name="IO4" x="-15.24" y="5.08" length="middle"/>
<pin name="IO16" x="-15.24" y="-25.4" length="middle"/>
<pin name="IO17" x="15.24" y="15.24" length="middle" rot="R180"/>
<pin name="IO5" x="-15.24" y="2.54" length="middle"/>
<pin name="IO18" x="15.24" y="12.7" length="middle" rot="R180"/>
<pin name="IO19" x="15.24" y="10.16" length="middle" rot="R180"/>
<pin name="IO21" x="15.24" y="5.08" length="middle" rot="R180"/>
<pin name="IO37" x="15.24" y="-2.54" length="middle" rot="R180"/>
<pin name="IO38" x="15.24" y="-5.08" length="middle" rot="R180"/>
<pin name="IO1" x="-15.24" y="12.7" length="middle"/>
<pin name="IO3" x="-15.24" y="7.62" length="middle"/>
<pin name="IO6" x="-15.24" y="0" length="middle"/>
<pin name="IO7" x="-15.24" y="-2.54" length="middle"/>
<pin name="IO8" x="-15.24" y="-5.08" length="middle"/>
<pin name="IO9" x="-15.24" y="-7.62" length="middle"/>
<pin name="IO10" x="-15.24" y="-10.16" length="middle"/>
<pin name="IO11" x="-15.24" y="-12.7" length="middle"/>
<pin name="IO36" x="15.24" y="0" length="middle" rot="R180"/>
<pin name="IO42" x="15.24" y="-15.24" length="middle" rot="R180"/>
<pin name="IO20" x="15.24" y="7.62" length="middle" rot="R180"/>
<pin name="TXD0" x="-15.24" y="20.32" length="middle"/>
<pin name="RXD0" x="-15.24" y="22.86" length="middle"/>
<pin name="IO45" x="15.24" y="-17.78" length="middle" rot="R180"/>
<pin name="IO46" x="15.24" y="-20.32" length="middle" rot="R180"/>
<pin name="IO47" x="15.24" y="-22.86" length="middle" rot="R180"/>
<pin name="IO48" x="15.24" y="-25.4" length="middle" rot="R180"/>
</symbol>
<symbol name="ESD9L5.0ST5G" library_version="26">
<wire x1="-1.27" y1="-1.27" x2="1.27" y2="0" width="0.254" layer="94"/>
<wire x1="1.27" y1="0" x2="-1.27" y2="1.27" width="0.254" layer="94"/>
<wire x1="1.27" y1="1.016" x2="1.27" y2="0" width="0.254" layer="94"/>
<wire x1="-1.27" y1="1.27" x2="-1.27" y2="-1.27" width="0.254" layer="94"/>
<wire x1="1.27" y1="0" x2="1.27" y2="-1.016" width="0.254" layer="94"/>
<text x="-5.08351875" y="2.92393125" size="1.78073125" layer="95">&gt;NAME</text>
<text x="-4.831390625" y="-3.945090625" size="1.7822" layer="96">&gt;VALUE</text>
<wire x1="1.27" y1="1.016" x2="0.508" y2="1.778" width="0.254" layer="94"/>
<wire x1="1.27" y1="-1.016" x2="2.032" y2="-1.778" width="0.254" layer="94"/>
<pin name="A" x="-5.08" y="0" visible="off" length="middle" direction="pas"/>
<pin name="C" x="5.08" y="0" visible="off" length="middle" direction="pas" rot="R180"/>
</symbol>
<symbol name="1N5819HW-7-F" library_version="26">
<text x="-5.08" y="2.54" size="1.778" layer="95">&gt;NAME</text>
<text x="-5.08" y="-3.81" size="1.778" layer="96">&gt;VALUE</text>
<wire x1="-1.27" y1="-1.27" x2="1.27" y2="0" width="0.254" layer="94"/>
<wire x1="1.27" y1="0" x2="-1.27" y2="1.27" width="0.254" layer="94"/>
<wire x1="1.905" y1="1.27" x2="1.27" y2="1.27" width="0.254" layer="94"/>
<wire x1="1.27" y1="1.27" x2="1.27" y2="0" width="0.254" layer="94"/>
<wire x1="-1.27" y1="1.27" x2="-1.27" y2="0" width="0.254" layer="94"/>
<wire x1="-1.27" y1="0" x2="-1.27" y2="-1.27" width="0.254" layer="94"/>
<wire x1="1.27" y1="0" x2="1.27" y2="-1.27" width="0.254" layer="94"/>
<wire x1="1.905" y1="1.27" x2="1.905" y2="1.016" width="0.254" layer="94"/>
<wire x1="1.27" y1="-1.27" x2="0.635" y2="-1.27" width="0.254" layer="94"/>
<wire x1="0.635" y1="-1.016" x2="0.635" y2="-1.27" width="0.254" layer="94"/>
<wire x1="-2.54" y1="0" x2="-1.27" y2="0" width="0.254" layer="94"/>
<wire x1="2.54" y1="0" x2="1.27" y2="0" width="0.254" layer="94"/>
<pin name="K" x="5.08" y="0" visible="off" length="short" direction="pas" rot="R180"/>
<pin name="A" x="-5.08" y="0" visible="off" length="short" direction="pas"/>
</symbol>
<symbol name="AP2112K-3.3TRG1" library_version="26">
<wire x1="-7.62" y1="7.62" x2="7.62" y2="7.62" width="0.41" layer="94"/>
<wire x1="7.62" y1="7.62" x2="7.62" y2="-7.62" width="0.41" layer="94"/>
<wire x1="7.62" y1="-7.62" x2="-7.62" y2="-7.62" width="0.41" layer="94"/>
<wire x1="-7.62" y1="-7.62" x2="-7.62" y2="7.62" width="0.41" layer="94"/>
<text x="-7.66295" y="8.647609375" size="2.08946875" layer="95" ratio="10" rot="SR0">&gt;NAME</text>
<text x="-7.6489" y="-11.6507" size="2.0883" layer="96" ratio="10" rot="SR0">&gt;VALUE</text>
<pin name="GND" x="12.7" y="-5.08" length="middle" direction="pwr" rot="R180"/>
<pin name="VIN" x="-12.7" y="5.08" length="middle" direction="pwr"/>
<pin name="VOUT" x="12.7" y="5.08" length="middle" direction="pwr" rot="R180"/>
<pin name="EN" x="-12.7" y="0" length="middle" direction="in"/>
</symbol>
<symbol name="BLM18BD601SN1D" library_version="26">
<wire x1="0" y1="0" x2="0.635" y2="1.905" width="0.254" layer="94"/>
<wire x1="0.635" y1="1.905" x2="1.905" y2="-1.905" width="0.254" layer="94"/>
<wire x1="1.905" y1="-1.905" x2="3.175" y2="1.905" width="0.254" layer="94"/>
<wire x1="3.175" y1="1.905" x2="4.445" y2="-1.905" width="0.254" layer="94"/>
<wire x1="4.445" y1="-1.905" x2="5.715" y2="1.905" width="0.254" layer="94"/>
<wire x1="5.715" y1="1.905" x2="6.985" y2="-1.905" width="0.254" layer="94"/>
<wire x1="6.985" y1="-1.905" x2="8.255" y2="1.905" width="0.254" layer="94"/>
<wire x1="8.255" y1="1.905" x2="9.525" y2="-1.905" width="0.254" layer="94"/>
<wire x1="9.525" y1="-1.905" x2="10.16" y2="0" width="0.254" layer="94"/>
<text x="-12.7044" y="5.08148125" size="2.54148125" layer="95">&gt;NAME</text>
<text x="-12.71" y="-5.086640625" size="2.54331875" layer="96">&gt;VALUE</text>
<wire x1="-12.7" y1="0" x2="-10.16" y2="0" width="0.254" layer="94" curve="-180"/>
<wire x1="-10.16" y1="0" x2="-7.62" y2="0" width="0.254" layer="94" curve="-180"/>
<wire x1="-7.62" y1="0" x2="-5.08" y2="0" width="0.254" layer="94" curve="-180"/>
<wire x1="-5.08" y1="0" x2="-2.54" y2="0" width="0.254" layer="94" curve="-180"/>
<wire x1="0" y1="0" x2="-2.54" y2="0" width="0.254" layer="94"/>
<pin name="2" x="12.7" y="0" visible="off" length="short" direction="pas" rot="R180"/>
<pin name="1" x="-15.24" y="0" visible="off" length="short" direction="pas"/>
</symbol>
</symbols>
<devicesets>
<deviceset name="MAX98357AETE+T" prefix="U" library_version="27">
<gates>
<gate name="G$1" symbol="MAX98357AETE+T" x="0" y="0"/>
</gates>
<devices>
<device name="" package="QFN50P300X300X80-17N">
<connects>
<connect gate="G$1" pin="BCLK" pad="16"/>
<connect gate="G$1" pin="DIN" pad="1"/>
<connect gate="G$1" pin="EP" pad="17"/>
<connect gate="G$1" pin="GAIN_SLOT" pad="2"/>
<connect gate="G$1" pin="GND" pad="3 11 15"/>
<connect gate="G$1" pin="LRCLK" pad="14"/>
<connect gate="G$1" pin="OUTN" pad="10"/>
<connect gate="G$1" pin="OUTP" pad="9"/>
<connect gate="G$1" pin="SD_MODE" pad="4"/>
<connect gate="G$1" pin="VDD" pad="7 8"/>
</connects>
<technologies>
<technology name="">
<attribute name="MF" value="Maxim Integrated"/>
<attribute name="DESCRIPTION" value=" Audio Amp Speaker 1-CH Mono Class-D 16-Pin TQFN EP T/R "/>
<attribute name="PACKAGE" value="TQFN-16 Maxim"/>
<attribute name="PRICE" value="None"/>
<attribute name="MP" value="MAX98357AETE+T"/>
<attribute name="AVAILABILITY" value="Unavailable"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="SM02B-SRSS-TB" prefix="J" library_version="27">
<gates>
<gate name="A" symbol="CONN_002P_000C_1" x="0" y="0"/>
</gates>
<devices>
<device name="CONN_SM02B-SRSS-TB_JST" package="CONN_SM02B-SRSS-TB_JST">
<connects>
<connect gate="A" pin="1" pad="1"/>
<connect gate="A" pin="2" pad="2"/>
</connects>
<technologies>
<technology name="">
<attribute name="COPYRIGHT" value="Copyright (C) 2026 Ultra Librarian. All rights reserved." constant="no"/>
<attribute name="MANUFACTURER_NAME" value="JST" constant="no"/>
<attribute name="MANUFACTURER_PART_NUMBER" value="SM02B-SRSS-TB" constant="no"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="KMR221GLFS" prefix="S" library_version="27">
<gates>
<gate name="G$1" symbol="KMR221GLFS" x="0" y="0"/>
</gates>
<devices>
<device name="" package="SW_KMR221GLFS">
<connects>
<connect gate="G$1" pin="1" pad="1 4"/>
<connect gate="G$1" pin="3" pad="2 3"/>
<connect gate="G$1" pin="5" pad="5"/>
</connects>
<technologies>
<technology name="">
<attribute name="MANUFACTURER" value="CnK"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="XL-5050RGBC-WS2812B" prefix="D" library_version="27">
<gates>
<gate name="G$1" symbol="XL-5050RGBC-WS2812B" x="0" y="0"/>
</gates>
<devices>
<device name="" package="LED_XL-5050RGBC-WS2812B">
<connects>
<connect gate="G$1" pin="DIN" pad="4"/>
<connect gate="G$1" pin="DOU" pad="2"/>
<connect gate="G$1" pin="GND" pad="3"/>
<connect gate="G$1" pin="VDD" pad="1"/>
</connects>
<technologies>
<technology name="">
<attribute name="MANUFACTURER" value="Xinglight"/>
<attribute name="PARTREV" value="N/A"/>
<attribute name="MAXIMUM_PACKAGE_HEIGHT" value="1.6mm"/>
<attribute name="STANDARD" value="Manufacturer Recommendations"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="UWJ1C101MCL1GB" prefix="C" library_version="27">
<gates>
<gate name="A" symbol="CAPH" x="0" y="0" swaplevel="1"/>
</gates>
<devices>
<device name="CAP_UWF_6P3X5P4_NCH" package="CAP_UWF_6P3X5P4_NCH">
<connects>
<connect gate="A" pin="1" pad="1"/>
<connect gate="A" pin="2" pad="2"/>
</connects>
<technologies>
<technology name="">
<attribute name="COPYRIGHT" value="Copyright (C) 2026 Ultra Librarian. All rights reserved." constant="no"/>
<attribute name="MANUFACTURER_NAME" value="Nichicon" constant="no"/>
<attribute name="MANUFACTURER_PART_NUMBER" value="UWJ1C101MCL1GB" constant="no"/>
</technology>
</technologies>
</device>
<device name="CAP_UWF_6P3X5P4_NCH-M" package="CAP_UWF_6P3X5P4_NCH-M">
<connects>
<connect gate="A" pin="1" pad="1"/>
<connect gate="A" pin="2" pad="2"/>
</connects>
<technologies>
<technology name="">
<attribute name="COPYRIGHT" value="Copyright (C) 2026 Ultra Librarian. All rights reserved." constant="no"/>
<attribute name="MANUFACTURER_NAME" value="Nichicon" constant="no"/>
<attribute name="MANUFACTURER_PART_NUMBER" value="UWJ1C101MCL1GB" constant="no"/>
</technology>
</technologies>
</device>
<device name="CAP_UWF_6P3X5P4_NCH-L" package="CAP_UWF_6P3X5P4_NCH-L">
<connects>
<connect gate="A" pin="1" pad="1"/>
<connect gate="A" pin="2" pad="2"/>
</connects>
<technologies>
<technology name="">
<attribute name="COPYRIGHT" value="Copyright (C) 2026 Ultra Librarian. All rights reserved." constant="no"/>
<attribute name="MANUFACTURER_NAME" value="Nichicon" constant="no"/>
<attribute name="MANUFACTURER_PART_NUMBER" value="UWJ1C101MCL1GB" constant="no"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="ICS-43432" prefix="MK" library_version="27">
<gates>
<gate name="G$1" symbol="ICS-43432" x="0" y="0"/>
</gates>
<devices>
<device name="" package="MIC_ICS-43432">
<connects>
<connect gate="G$1" pin="CONFIG" pad="2"/>
<connect gate="G$1" pin="GND" pad="4"/>
<connect gate="G$1" pin="LR" pad="1"/>
<connect gate="G$1" pin="SCK" pad="6"/>
<connect gate="G$1" pin="SD" pad="7"/>
<connect gate="G$1" pin="VDD" pad="3"/>
<connect gate="G$1" pin="WS" pad="5"/>
</connects>
<technologies>
<technology name="">
<attribute name="MANUFACTURER" value="TDK Invensense"/>
<attribute name="PARTREV" value="1.3"/>
<attribute name="MAXIMUM_PACKAGE_HEIGHT" value="1.1mm"/>
<attribute name="STANDARD" value="Manufacturer Recommendations"/>
<attribute name="SNAPEDA_PN" value="ICS-43432"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="USB4120-03-C_REVA6" prefix="J" library_version="27">
<gates>
<gate name="G$1" symbol="USB4120-03-C_REVA6" x="0" y="0"/>
</gates>
<devices>
<device name="" package="GCT_USB4120-03-C_REVA6">
<connects>
<connect gate="G$1" pin="CC1" pad="A5"/>
<connect gate="G$1" pin="CC2" pad="B5"/>
<connect gate="G$1" pin="D1+" pad="A6"/>
<connect gate="G$1" pin="D1-" pad="A7"/>
<connect gate="G$1" pin="D2+" pad="B6"/>
<connect gate="G$1" pin="D2-" pad="B7"/>
<connect gate="G$1" pin="GND_A" pad="A1 A12"/>
<connect gate="G$1" pin="GND_B" pad="B1 B12"/>
<connect gate="G$1" pin="SBU1" pad="A8"/>
<connect gate="G$1" pin="SBU2" pad="B8"/>
<connect gate="G$1" pin="SHIELD" pad="S1 S2 S3 S4"/>
<connect gate="G$1" pin="VBUS_A" pad="A4 A9"/>
<connect gate="G$1" pin="VBUS_B" pad="B4 B9"/>
</connects>
<technologies>
<technology name="">
<attribute name="MANUFACTURER" value="Global Connector Technology"/>
<attribute name="PARTREV" value="A6"/>
<attribute name="MAXIMUM_PACKAGE_HEIGHT" value="6.5mm"/>
<attribute name="STANDARD" value="Manufacturer Recommendations"/>
<attribute name="SNAPEDA_PN" value="USB4120-03-C"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="ESP32-S3-WROOM-1-N8R8" prefix="U" library_version="27">
<gates>
<gate name="G$1" symbol="ESP32-S3-WROOM-1-N8R8" x="0" y="0"/>
</gates>
<devices>
<device name="" package="XCVR_ESP32S3WROOM1N8R8">
<connects>
<connect gate="G$1" pin="3V3" pad="2"/>
<connect gate="G$1" pin="EN" pad="3"/>
<connect gate="G$1" pin="GND" pad="1 40 41_1 41_2 41_3 41_4 41_5 41_6 41_7 41_8 41_9 41_10 41_11 41_12 41_13 41_14 41_15 41_16 41_17 41_18 41_19 41_20 41_21"/>
<connect gate="G$1" pin="IO0" pad="27"/>
<connect gate="G$1" pin="IO1" pad="39"/>
<connect gate="G$1" pin="IO10" pad="18"/>
<connect gate="G$1" pin="IO11" pad="19"/>
<connect gate="G$1" pin="IO12" pad="20"/>
<connect gate="G$1" pin="IO13" pad="21"/>
<connect gate="G$1" pin="IO14" pad="22"/>
<connect gate="G$1" pin="IO15" pad="8"/>
<connect gate="G$1" pin="IO16" pad="9"/>
<connect gate="G$1" pin="IO17" pad="10"/>
<connect gate="G$1" pin="IO18" pad="11"/>
<connect gate="G$1" pin="IO19" pad="13"/>
<connect gate="G$1" pin="IO2" pad="38"/>
<connect gate="G$1" pin="IO20" pad="14"/>
<connect gate="G$1" pin="IO21" pad="23"/>
<connect gate="G$1" pin="IO3" pad="15"/>
<connect gate="G$1" pin="IO35" pad="28"/>
<connect gate="G$1" pin="IO36" pad="29"/>
<connect gate="G$1" pin="IO37" pad="30"/>
<connect gate="G$1" pin="IO38" pad="31"/>
<connect gate="G$1" pin="IO39" pad="32"/>
<connect gate="G$1" pin="IO4" pad="4"/>
<connect gate="G$1" pin="IO40" pad="33"/>
<connect gate="G$1" pin="IO41" pad="34"/>
<connect gate="G$1" pin="IO42" pad="35"/>
<connect gate="G$1" pin="IO45" pad="26"/>
<connect gate="G$1" pin="IO46" pad="16"/>
<connect gate="G$1" pin="IO47" pad="24"/>
<connect gate="G$1" pin="IO48" pad="25"/>
<connect gate="G$1" pin="IO5" pad="5"/>
<connect gate="G$1" pin="IO6" pad="6"/>
<connect gate="G$1" pin="IO7" pad="7"/>
<connect gate="G$1" pin="IO8" pad="12"/>
<connect gate="G$1" pin="IO9" pad="17"/>
<connect gate="G$1" pin="RXD0" pad="36"/>
<connect gate="G$1" pin="TXD0" pad="37"/>
</connects>
<technologies>
<technology name="">
<attribute name="MF" value="Espressif Systems"/>
<attribute name="DESCRIPTION" value=" Bluetooth, WiFi 802.11b/g/n, Bluetooth v5.0 Transceiver Module 2.4GHz PCB Trace Surface Mount "/>
<attribute name="PACKAGE" value="SMD-41 Espressif Systems"/>
<attribute name="PRICE" value="None"/>
<attribute name="MP" value="ESP32S3WROOM1N8R8"/>
<attribute name="AVAILABILITY" value="In Stock"/>
<attribute name="PURCHASE-URL" value="https://pricing.snapeda.com/search/part/ESP32S3WROOM1N8R8/?ref=eda"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="ESD9L5.0ST5G" prefix="D" library_version="27">
<gates>
<gate name="G$1" symbol="ESD9L5.0ST5G" x="0" y="0"/>
</gates>
<devices>
<device name="" package="DIOM1006X40N">
<connects>
<connect gate="G$1" pin="A" pad="A"/>
<connect gate="G$1" pin="C" pad="C"/>
</connects>
<technologies>
<technology name="">
<attribute name="MANUFACTURER" value="OnSemi"/>
<attribute name="PARTREV" value="7"/>
<attribute name="MAXIMUM_PACKAGE_HEIGHT" value="0.4mm"/>
<attribute name="STANDARD" value="IPC-7351B"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="1N5819HW-7-F" prefix="D" library_version="27">
<gates>
<gate name="G$1" symbol="1N5819HW-7-F" x="0" y="0"/>
</gates>
<devices>
<device name="" package="SOD3715X145N">
<connects>
<connect gate="G$1" pin="A" pad="A"/>
<connect gate="G$1" pin="K" pad="C"/>
</connects>
<technologies>
<technology name="">
<attribute name="MANUFACTURER" value="Diodes Inc."/>
<attribute name="PARTREV" value="18-2"/>
<attribute name="STANDARD" value="IPC-7351B"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="AP2112K-3.3TRG1" prefix="U" library_version="27">
<gates>
<gate name="G$1" symbol="AP2112K-3.3TRG1" x="0" y="0"/>
</gates>
<devices>
<device name="" package="SOT95P285X140-5N">
<connects>
<connect gate="G$1" pin="EN" pad="3"/>
<connect gate="G$1" pin="GND" pad="2"/>
<connect gate="G$1" pin="VIN" pad="1"/>
<connect gate="G$1" pin="VOUT" pad="5"/>
</connects>
<technologies>
<technology name="">
<attribute name="MANUFACTURER" value="Diodes Inc."/>
<attribute name="PARTREV" value="2-2"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
<deviceset name="BLM18BD601SN1D" prefix="FL" library_version="27">
<gates>
<gate name="G$1" symbol="BLM18BD601SN1D" x="0" y="0"/>
</gates>
<devices>
<device name="" package="BEADC1608X95N">
<connects>
<connect gate="G$1" pin="1" pad="1"/>
<connect gate="G$1" pin="2" pad="2"/>
</connects>
<technologies>
<technology name=""/>
</technologies>
</device>
</devices>
</deviceset>
</devicesets>
</library>
<library name="BSS138" urn="urn:adsk.wipprod:fs.file:vf.hNoH06g9QtOYjlRLYUNKqw">
<packages>
<package name="SOT95P240X111-3N" library_version="2">
<wire x1="-0.65" y1="-1.45" x2="-0.65" y2="1.45" width="0.127" layer="51"/>
<wire x1="-0.65" y1="1.45" x2="0.65" y2="1.45" width="0.127" layer="51"/>
<wire x1="0.65" y1="1.45" x2="0.65" y2="-1.45" width="0.127" layer="51"/>
<wire x1="0.65" y1="-1.45" x2="-0.65" y2="-1.45" width="0.127" layer="51"/>
<wire x1="-0.65" y1="1.57" x2="0.65" y2="1.57" width="0.127" layer="21"/>
<wire x1="-0.65" y1="-1.57" x2="0.65" y2="-1.57" width="0.127" layer="21"/>
<wire x1="-1.925" y1="1.7" x2="1.925" y2="1.7" width="0.05" layer="39"/>
<wire x1="1.925" y1="-1.7" x2="-1.925" y2="-1.7" width="0.05" layer="39"/>
<wire x1="-1.925" y1="-1.7" x2="-1.925" y2="1.7" width="0.05" layer="39"/>
<wire x1="1.925" y1="-1.7" x2="1.925" y2="1.7" width="0.05" layer="39"/>
<circle x="-2.25" y="1.3" radius="0.1" width="0.2" layer="21"/>
<circle x="-2.25" y="1.3" radius="0.1" width="0.2" layer="51"/>
<text x="-2" y="2" size="0.8128" layer="25">&gt;NAME</text>
<text x="-2" y="-2" size="0.8128" layer="27" align="top-left">&gt;VALUE</text>
<wire x1="0.65" y1="1.57" x2="0.65" y2="0.62" width="0.127" layer="21"/>
<wire x1="0.65" y1="-1.57" x2="0.65" y2="-0.62" width="0.127" layer="21"/>
<smd name="1" x="-1.06" y="0.95" dx="1.23" dy="0.6" layer="1" roundness="25"/>
<smd name="3" x="1.06" y="0" dx="1.23" dy="0.6" layer="1" roundness="25"/>
<smd name="2" x="-1.06" y="-0.95" dx="1.23" dy="0.6" layer="1" roundness="25"/>
</package>
</packages>
<symbols>
<symbol name="BSS138" library_version="2">
<wire x1="0.762" y1="0.762" x2="0.762" y2="0" width="0.254" layer="94"/>
<wire x1="0.762" y1="0" x2="0.762" y2="-0.762" width="0.254" layer="94"/>
<wire x1="0.762" y1="3.175" x2="0.762" y2="2.54" width="0.254" layer="94"/>
<wire x1="0.762" y1="2.54" x2="0.762" y2="1.905" width="0.254" layer="94"/>
<wire x1="0.762" y1="0" x2="2.54" y2="0" width="0.1524" layer="94"/>
<wire x1="2.54" y1="0" x2="2.54" y2="-2.54" width="0.1524" layer="94"/>
<wire x1="0.762" y1="-1.905" x2="0.762" y2="-2.54" width="0.254" layer="94"/>
<wire x1="0.762" y1="-2.54" x2="0.762" y2="-3.175" width="0.254" layer="94"/>
<wire x1="0" y1="2.54" x2="0" y2="-2.54" width="0.254" layer="94"/>
<wire x1="2.54" y1="-2.54" x2="0.762" y2="-2.54" width="0.1524" layer="94"/>
<wire x1="3.81" y1="2.54" x2="3.81" y2="0.508" width="0.1524" layer="94"/>
<wire x1="3.81" y1="0.508" x2="3.81" y2="-2.54" width="0.1524" layer="94"/>
<wire x1="2.54" y1="-2.54" x2="3.81" y2="-2.54" width="0.1524" layer="94"/>
<wire x1="0.762" y1="2.54" x2="3.81" y2="2.54" width="0.1524" layer="94"/>
<wire x1="4.572" y1="0.762" x2="4.318" y2="0.508" width="0.1524" layer="94"/>
<wire x1="4.318" y1="0.508" x2="3.81" y2="0.508" width="0.1524" layer="94"/>
<wire x1="3.81" y1="0.508" x2="3.302" y2="0.508" width="0.1524" layer="94"/>
<wire x1="3.302" y1="0.508" x2="3.048" y2="0.254" width="0.1524" layer="94"/>
<circle x="2.54" y="-2.54" radius="0.3592" width="0" layer="94"/>
<circle x="2.54" y="2.54" radius="0.3592" width="0" layer="94"/>
<text x="-8.89" y="-7.62" size="1.778" layer="96">&gt;VALUE</text>
<text x="-8.89" y="2.54" size="1.778" layer="95">&gt;NAME</text>
<polygon width="0.1524" layer="94" pour="solid">
<vertex x="3.302" y="-0.254"/>
<vertex x="4.318" y="-0.254"/>
<vertex x="3.81" y="0.508003125"/>
</polygon>
<polygon width="0.1524" layer="94" pour="solid">
<vertex x="1.015996875" y="0"/>
<vertex x="2.032" y="-0.761996875"/>
<vertex x="2.032" y="0.761996875"/>
</polygon>
<pin name="S" x="2.54" y="-5.08" visible="off" length="short" direction="pas" rot="R90"/>
<pin name="G" x="-2.54" y="-2.54" visible="off" length="short" direction="pas"/>
<pin name="D" x="2.54" y="5.08" visible="off" length="short" direction="pas" rot="R270"/>
</symbol>
</symbols>
<devicesets>
<deviceset name="BSS138" prefix="Q" library_version="2">
<description> &lt;a href="https://pricing.snapeda.com/parts/BSS138/onsemi/view-part?ref=eda"&gt;Check availability&lt;/a&gt;</description>
<gates>
<gate name="G$1" symbol="BSS138" x="0" y="0"/>
</gates>
<devices>
<device name="" package="SOT95P240X111-3N">
<connects>
<connect gate="G$1" pin="D" pad="3"/>
<connect gate="G$1" pin="G" pad="1"/>
<connect gate="G$1" pin="S" pad="2"/>
</connects>
<technologies>
<technology name="">
<attribute name="MF" value="onsemi"/>
<attribute name="DESCRIPTION" value="                                                      N-Channel 50 V 220mA (Ta) 350mW (Ta) Surface Mount SOT-23-3                                              "/>
<attribute name="PACKAGE" value="SOT-23-3 ON Semiconductor"/>
<attribute name="PRICE" value="None"/>
<attribute name="SNAPEDA_LINK" value="https://www.snapeda.com/parts/BSS138/Onsemi/view-part/?ref=snap"/>
<attribute name="MP" value="BSS138"/>
<attribute name="AVAILABILITY" value="In Stock"/>
<attribute name="CHECK_PRICES" value="https://www.snapeda.com/parts/BSS138/Onsemi/view-part/?ref=eda"/>
<attribute name="LCSC_PART" value="C82045"/>
</technology>
</technologies>
</device>
</devices>
</deviceset>
</devicesets>
</library>
</libraries>
<attributes>
</attributes>
<variantdefs>
</variantdefs>
<classes>
<class number="0" name="default" width="0" drill="0">
</class>
<class number="1" name="PWR_HV" width="0" drill="0">
</class>
<class number="2" name="PWR_5V" width="0.508" drill="0">
</class>
<class number="3" name="PWR_3V3" width="0.1524" drill="0">
</class>
<class number="4" name="SIG" width="0.1524" drill="0">
</class>
<class number="5" name="USB" width="0" drill="0">
</class>
</classes>
<parts>
<part name="U1" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="ESP32-S3-WROOM-1-N8R8" device="">
<attribute name="LCSC" value="C2913201"/>
</part>
<part name="SUPPLY17" library="Tutorial - Fusion 360" library_urn="urn:adsk.eagle:library:16997205" deviceset="GND" device="" value="GND"/>
<part name="D1" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="ESD9L5.0ST5G" device="">
<attribute name="LCSC" value="C82326"/>
</part>
<part name="D5" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="ESD9L5.0ST5G" device="">
<attribute name="LCSC" value="C82326"/>
</part>
<part name="D9" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="ESD9L5.0ST5G" device="">
<attribute name="LCSC" value="C82326"/>
</part>
<part name="D13" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="1N5819HW-7-F" device="">
<attribute name="LCSC" value="C82544"/>
</part>
<part name="C1" library="Tutorial - Fusion 360" library_urn="urn:adsk.eagle:library:16997205" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/5" technology="_" value="10uF/25V (20%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C15850"/>
</part>
<part name="C5" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/6" technology="_" value="10uF/25V (20%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C15850"/>
</part>
<part name="C9" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/6" technology="_" value="0.1uF/50V(10%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C49678"/>
</part>
<part name="SUPPLY1" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="R1" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R-US" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16378559/7" technology="_" value="10K(1%)">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C17414"/>
</part>
<part name="C12" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/6" technology="_" value="1uF/16V(10%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C28323"/>
</part>
<part name="SUPPLY9" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY13" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="U2" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="AP2112K-3.3TRG1" device="">
<attribute name="LCSC" value="C51118"/>
</part>
<part name="SUPPLY21" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="C17" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/6" technology="_" value="10uF/25V(20%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C15850"/>
</part>
<part name="C18" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/6" technology="_" value="0.1uF/50V(10%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C49678"/>
</part>
<part name="SUPPLY25" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="C19" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/6" technology="_" value="0.1uF/50V(10%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C49678"/>
</part>
<part name="C20" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/6" technology="_" value="10uF/25V(20%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C15850"/>
</part>
<part name="SUPPLY29" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="R2" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16378559/7" technology="_" value="5.1K (1%)">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C27834"/>
</part>
<part name="D18" library="LED" library_urn="urn:adsk.eagle:library:22900745" deviceset="CHIP-FLAT-R" device="_0805" package3d_urn="urn:adsk.eagle:package:24294806/3" value="CHIP-FLAT-R_0805">
<attribute name="LCSC" value="C84256"/>
</part>
<part name="SUPPLY33" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY34" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY35" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="C21" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/6" technology="_" value="0.1uF/50V(10%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C49678"/>
</part>
<part name="C22" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/6" technology="_" value="0.1uF/50V(10%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C49678"/>
</part>
<part name="R6" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R-US" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16378559/7" technology="_" value="10K(1%)">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C17414"/>
</part>
<part name="FL3" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="BLM18BD601SN1D" device="">
<attribute name="LCSC" value="C1002"/>
</part>
<part name="U3" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="MAX98357AETE+T" device="">
<attribute name="LCSC" value="C910544"/>
</part>
<part name="R3" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16378565/7" technology="_" value="1M">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C22935"/>
</part>
<part name="SUPPLY2" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="VDD" device="" value="VDD"/>
<part name="SUPPLY3" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="C2" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16290898/6" technology="_" value="220pF">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C27675"/>
</part>
<part name="C3" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16290898/6" technology="_" value="220pF">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C27675"/>
</part>
<part name="SUPPLY4" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY6" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY7" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="VDD" device="" value="VDD"/>
<part name="C4" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16290898/6" technology="_" value="10uF">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C1691"/>
</part>
<part name="C6" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16290898/6" technology="_" value="0.1uF">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C14663"/>
</part>
<part name="SUPPLY8" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY10" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY22" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY23" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="VDD" device="" value="VDD"/>
<part name="R8" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16378565/7" technology="_" value="10K">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C25804"/>
</part>
<part name="SUPPLY24" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="R9" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16378565/7" technology="_" value="68">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C23220"/>
</part>
<part name="SUPPLY12" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="C7" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0805(2012-METRIC)" package3d_urn="urn:adsk.eagle:package:16290897/6" technology="_" value="0.1uF/50V(10%)">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C49678"/>
</part>
<part name="R4" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16378565/7" technology="_" value="5k1">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C23186"/>
</part>
<part name="SUPPLY14" library="Tutorial - Fusion 360" library_urn="urn:adsk.eagle:library:16997205" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY15" library="Tutorial - Fusion 360" library_urn="urn:adsk.eagle:library:16997205" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY16" library="Tutorial - Fusion 360" library_urn="urn:adsk.eagle:library:16997205" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY18" library="Tutorial - Fusion 360" library_urn="urn:adsk.eagle:library:16997205" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY19" library="Tutorial - Fusion 360" library_urn="urn:adsk.eagle:library:16997205" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY20" library="Tutorial - Fusion 360" library_urn="urn:adsk.eagle:library:16997205" deviceset="GND" device="" value="GND"/>
<part name="SUPPLY26" library="Tutorial - Fusion 360" library_urn="urn:adsk.eagle:library:16997205" deviceset="GND" device="" value="GND"/>
<part name="R5" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16378565/7" technology="_" value="5k1">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C23186"/>
</part>
<part name="SUPPLY27" library="Tutorial - Fusion 360" library_urn="urn:adsk.eagle:library:16997205" deviceset="GND" device="" value="GND"/>
<part name="JP1" library="Connector" library_urn="urn:adsk.eagle:library:16378166" deviceset="PINHD-1X3" device="" package3d_urn="urn:adsk.eagle:package:47493647/1">
<attribute name="LCSC" value="C49257"/>
</part>
<part name="SUPPLY5" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="J1" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="SM02B-SRSS-TB" device="CONN_SM02B-SRSS-TB_JST">
<attribute name="LCSC" value="C160402"/>
</part>
<part name="S1" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="KMR221GLFS" device="">
<attribute name="LCSC" value="C72443"/>
</part>
<part name="S2" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="KMR221GLFS" device="">
<attribute name="LCSC" value="C72443"/>
</part>
<part name="S3" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="KMR221GLFS" device="">
<attribute name="LCSC" value="C72443"/>
</part>
<part name="D2" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="XL-5050RGBC-WS2812B" device="">
<attribute name="LCSC" value="C2843785"/>
</part>
<part name="C8" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="UWJ1C101MCL1GB" device="CAP_UWF_6P3X5P4_NCH">
<attribute name="LCSC" value="C2887276"/>
</part>
<part name="Q1" library="BSS138" library_urn="urn:adsk.wipprod:fs.file:vf.hNoH06g9QtOYjlRLYUNKqw" deviceset="BSS138" device="">
<attribute name="LCSC" value="C52895"/>
</part>
<part name="R7" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16378565/7" technology="_" value="10K">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C25804"/>
</part>
<part name="R10" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16378565/7" technology="_" value="10K">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C25804"/>
</part>
<part name="C10" library="Capacitor" library_urn="urn:adsk.eagle:library:16290819" deviceset="C" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16290898/6" technology="_" value="0.1uF">
<spice>
<pinmapping spiceprefix="C">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C14663"/>
</part>
<part name="JP2" library="Connector" library_urn="urn:adsk.eagle:library:16378166" deviceset="PINHD-1X10" device="" package3d_urn="urn:adsk.eagle:package:47493623/1">
<attribute name="LCSC" value="C57369"/>
</part>
<part name="JP3" library="Connector" library_urn="urn:adsk.eagle:library:16378166" deviceset="PINHD-1X10" device="" package3d_urn="urn:adsk.eagle:package:47493623/1">
<attribute name="LCSC" value="C57369"/>
</part>
<part name="FL1" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="BLM18BD601SN1D" device="">
<attribute name="LCSC" value="C1002"/>
</part>
<part name="MK1" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="ICS-43432" device="">
<attribute name="LCSC" value="C574021"/>
</part>
<part name="J3" library="Ducky Library" library_urn="urn:adsk.wipprod:fs.file:vf.1ZVydtunQ3G7JfVPz05osQ" deviceset="USB4120-03-C_REVA6" device="">
<attribute name="LCSC" value="C3445864"/>
</part>
<part name="SUPPLY11" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
<part name="R11" library="Resistor" library_urn="urn:adsk.eagle:library:16378527" deviceset="R" device="CHIP-0603(1608-METRIC)" package3d_urn="urn:adsk.eagle:package:16378565/7" technology="_" value="100K">
<spice>
<pinmapping spiceprefix="R">
<pinmap gate="G$1" pin="1" pinorder="1"/>
<pinmap gate="G$1" pin="2" pinorder="2"/>
</pinmapping>
</spice>
<attribute name="LCSC" value="C25803"/>
</part>
<part name="SUPPLY28" library="Power_Symbols" library_urn="urn:adsk.eagle:library:16502351" deviceset="GND" device="" value="GND"/>
</parts>
<sheets>
<sheet>
<plain>
<text x="-45.72" y="167.64" size="5.08" layer="97">USB C</text>
<text x="157.48" y="-58.42" size="5.08" layer="97">SERVO</text>
<text x="-43.18" y="50.8" size="5.08" layer="97">ESP32 S3</text>
<text x="-50.8" y="-48.26" size="5.08" layer="97">NEOPIXEL LED</text>
<text x="154.94" y="116.84" size="5.08" layer="97">VOLTAGE REGULATOR</text>
<text x="152.4" y="17.78" size="5.08" layer="97">BOOT &amp; RESET SWITCHES</text>
<text x="149.86" y="-121.92" size="5.08" layer="97">SPEAKER AMP</text>
<text x="213.36" y="-58.42" size="5.08" layer="97">SPEAKER</text>
<text x="182.88" y="-129.54" size="1.778" layer="97">NEED TO ADD FERRITES TO V0- &amp; V0+
</text>
<text x="-45.72" y="-116.84" size="5.08" layer="97">MIC</text>
</plain>
<instances>
<instance part="U1" gate="G$1" x="-10.16" y="0" smashed="yes">
<attribute name="NAME" x="-20.32" y="34.1122" size="1.778" layer="95"/>
<attribute name="VALUE" x="-20.32" y="-35.56" size="1.778" layer="96"/>
<attribute name="LCSC" x="-10.16" y="0" size="1.778" layer="96" display="off"/>
</instance>
<instance part="SUPPLY17" gate="G$1" x="15.24" y="-30.48" smashed="yes" rot="R90">
<attribute name="VALUE" x="18.415" y="-30.353" size="1.778" layer="96" rot="R90" align="bottom-center"/>
</instance>
<instance part="D1" gate="G$1" x="-22.86" y="121.92" smashed="yes" rot="R270">
<attribute name="NAME" x="-22.47606875" y="127.00351875" size="1.78073125" layer="95" rot="R270"/>
<attribute name="VALUE" x="-26.805090625" y="126.751390625" size="1.7822" layer="96" rot="R270"/>
<attribute name="LCSC" x="-22.86" y="121.92" size="1.778" layer="96" rot="R270" display="off"/>
</instance>
<instance part="D5" gate="G$1" x="86.36" y="114.3" smashed="yes" rot="R270">
<attribute name="NAME" x="86.74393125" y="119.38351875" size="1.78073125" layer="95" rot="R270"/>
<attribute name="VALUE" x="82.414909375" y="119.131390625" size="1.7822" layer="96" rot="R270"/>
<attribute name="LCSC" x="86.36" y="114.3" size="1.778" layer="96" rot="R270" display="off"/>
</instance>
<instance part="D9" gate="G$1" x="76.2" y="114.3" smashed="yes" rot="R270">
<attribute name="NAME" x="76.58393125" y="119.38351875" size="1.78073125" layer="95" rot="R270"/>
<attribute name="VALUE" x="72.254909375" y="119.131390625" size="1.7822" layer="96" rot="R270"/>
<attribute name="LCSC" x="76.2" y="114.3" size="1.778" layer="96" rot="R270" display="off"/>
</instance>
<instance part="D13" gate="G$1" x="-35.56" y="142.24" smashed="yes" rot="R180">
<attribute name="NAME" x="-27.94" y="142.24" size="1.778" layer="95" rot="R180"/>
<attribute name="VALUE" x="-22.86" y="146.05" size="1.778" layer="96" rot="R180"/>
<attribute name="LCSC" x="-35.56" y="142.24" size="1.778" layer="96" rot="R180" display="off"/>
</instance>
<instance part="C1" gate="G$1" x="-43.18" y="134.62" smashed="yes">
<attribute name="NAME" x="-48.26" y="134.62" size="1.778" layer="95"/>
<attribute name="VALUE" x="-53.34" y="127" size="1.778" layer="96"/>
<attribute name="LCSC" x="-43.18" y="134.62" size="1.778" layer="96" display="off"/>
</instance>
<instance part="C5" gate="G$1" x="50.8" y="20.32" smashed="yes" rot="R90">
<attribute name="NAME" x="48.26" y="20.32" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="53.34" y="20.32" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="50.8" y="20.32" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="C9" gate="G$1" x="63.5" y="20.32" smashed="yes" rot="R90">
<attribute name="NAME" x="60.96" y="20.32" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="66.04" y="20.32" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="63.5" y="20.32" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY1" gate="G$1" x="50.8" y="-10.16" smashed="yes">
<attribute name="VALUE" x="50.8" y="-12.7" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="R1" gate="G$1" x="93.98" y="30.48" smashed="yes" rot="R90">
<attribute name="NAME" x="91.44" y="30.48" size="1.778" layer="95" rot="R90" align="center"/>
<attribute name="VALUE" x="96.52" y="30.48" size="1.778" layer="96" rot="R90" align="center"/>
<attribute name="LCSC" x="93.98" y="30.48" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="C12" gate="G$1" x="93.98" y="7.62" smashed="yes" rot="R90">
<attribute name="NAME" x="91.44" y="7.62" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="96.52" y="7.62" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="93.98" y="7.62" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY9" gate="G$1" x="93.98" y="-2.54" smashed="yes">
<attribute name="VALUE" x="93.98" y="-5.08" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="SUPPLY13" gate="G$1" x="63.5" y="-86.36" smashed="yes" rot="R90">
<attribute name="VALUE" x="66.04" y="-86.36" size="1.778" layer="96" rot="R90" align="top-center"/>
</instance>
<instance part="U2" gate="G$1" x="195.58" y="83.82" smashed="yes">
<attribute name="NAME" x="187.91705" y="92.467609375" size="2.08946875" layer="95" ratio="10" rot="SR0"/>
<attribute name="VALUE" x="187.9311" y="72.1693" size="2.0883" layer="96" ratio="10" rot="SR0"/>
<attribute name="LCSC" x="195.58" y="83.82" size="1.778" layer="96" display="off"/>
</instance>
<instance part="SUPPLY21" gate="G$1" x="213.36" y="78.74" smashed="yes" rot="R90">
<attribute name="VALUE" x="215.9" y="78.74" size="1.778" layer="96" rot="R90" align="top-center"/>
</instance>
<instance part="C17" gate="G$1" x="154.94" y="76.2" smashed="yes" rot="R90">
<attribute name="NAME" x="152.4" y="76.2" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="157.48" y="76.2" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="154.94" y="76.2" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="C18" gate="G$1" x="167.64" y="76.2" smashed="yes" rot="R90">
<attribute name="NAME" x="165.1" y="76.2" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="170.18" y="76.2" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="167.64" y="76.2" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY25" gate="G$1" x="154.94" y="55.88" smashed="yes">
<attribute name="VALUE" x="154.94" y="53.34" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="C19" gate="G$1" x="226.06" y="76.2" smashed="yes" rot="R90">
<attribute name="NAME" x="223.52" y="76.2" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="228.6" y="76.2" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="226.06" y="76.2" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="C20" gate="G$1" x="238.76" y="76.2" smashed="yes" rot="R90">
<attribute name="NAME" x="236.22" y="76.2" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="241.3" y="76.2" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="238.76" y="76.2" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY29" gate="G$1" x="238.76" y="53.34" smashed="yes">
<attribute name="VALUE" x="238.76" y="50.8" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="R2" gate="G$1" x="256.54" y="88.9" smashed="yes">
<attribute name="NAME" x="256.54" y="91.44" size="1.778" layer="95" align="bottom-center"/>
<attribute name="VALUE" x="256.54" y="86.36" size="1.778" layer="96" align="top-center"/>
<attribute name="LCSC" x="256.54" y="88.9" size="1.778" layer="96" display="off"/>
</instance>
<instance part="D18" gate="G$1" x="266.7" y="78.74" smashed="yes" rot="R270">
<attribute name="NAME" x="261.62" y="78.74" size="1.778" layer="95" rot="R270" align="bottom-center"/>
<attribute name="VALUE" x="271.78" y="76.2" size="1.778" layer="96" rot="R270" align="center"/>
<attribute name="LCSC" x="266.7" y="78.74" size="1.778" layer="96" rot="R270" display="off"/>
</instance>
<instance part="SUPPLY33" gate="G$1" x="266.7" y="53.34" smashed="yes">
<attribute name="VALUE" x="266.7" y="50.8" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="SUPPLY34" gate="G$1" x="154.94" y="-22.86" smashed="yes">
<attribute name="VALUE" x="154.94" y="-25.4" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="SUPPLY35" gate="G$1" x="220.98" y="-20.32" smashed="yes">
<attribute name="VALUE" x="220.98" y="-22.86" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="C21" gate="G$1" x="170.18" y="-15.24" smashed="yes" rot="R180">
<attribute name="NAME" x="170.18" y="-17.78" size="1.778" layer="95" rot="R180" align="bottom-center"/>
<attribute name="VALUE" x="170.18" y="-12.7" size="1.778" layer="96" rot="R180" align="top-center"/>
<attribute name="LCSC" x="170.18" y="-15.24" size="1.778" layer="96" rot="R180" display="off"/>
</instance>
<instance part="C22" gate="G$1" x="238.76" y="-12.7" smashed="yes" rot="R180">
<attribute name="NAME" x="238.76" y="-15.24" size="1.778" layer="95" rot="R180" align="bottom-center"/>
<attribute name="VALUE" x="238.76" y="-10.16" size="1.778" layer="96" rot="R180" align="top-center"/>
<attribute name="LCSC" x="238.76" y="-12.7" size="1.778" layer="96" rot="R180" display="off"/>
</instance>
<instance part="R6" gate="G$1" x="68.58" y="-20.32" smashed="yes" rot="R90">
<attribute name="NAME" x="66.04" y="-20.32" size="1.778" layer="95" rot="R90" align="center"/>
<attribute name="VALUE" x="71.12" y="-20.32" size="1.778" layer="96" rot="R90" align="center"/>
<attribute name="LCSC" x="68.58" y="-20.32" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="FL3" gate="G$1" x="30.48" y="30.48" smashed="yes">
<attribute name="NAME" x="17.7756" y="35.56148125" size="2.54148125" layer="95"/>
<attribute name="VALUE" x="17.77" y="25.393359375" size="2.54331875" layer="96"/>
<attribute name="LCSC" x="30.48" y="30.48" size="1.778" layer="96" display="off"/>
</instance>
<instance part="U3" gate="G$1" x="182.88" y="-149.86" smashed="yes">
<attribute name="NAME" x="170.18" y="-133.62" size="2.0828" layer="95" ratio="10" rot="SR0"/>
<attribute name="VALUE" x="170.18" y="-169.1" size="2.0828" layer="96" ratio="10" rot="SR0"/>
<attribute name="LCSC" x="182.88" y="-149.86" size="1.778" layer="96" display="off"/>
</instance>
<instance part="R3" gate="G$1" x="162.56" y="-162.56" smashed="yes" rot="R90">
<attribute name="NAME" x="160.02" y="-162.56" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="165.1" y="-162.56" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="162.56" y="-162.56" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY2" gate="G$1" x="162.56" y="-172.72" smashed="yes" rot="R180">
<attribute name="VALUE" x="162.56" y="-177.8" size="1.778" layer="96" rot="R180" align="top-center"/>
</instance>
<instance part="SUPPLY3" gate="G$1" x="203.2" y="-175.26" smashed="yes">
<attribute name="VALUE" x="203.2" y="-177.8" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="C2" gate="G$1" x="223.52" y="-154.94" smashed="yes" rot="R90">
<attribute name="NAME" x="220.98" y="-154.94" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="226.06" y="-154.94" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="223.52" y="-154.94" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="C3" gate="G$1" x="213.36" y="-154.94" smashed="yes" rot="R90">
<attribute name="NAME" x="210.82" y="-154.94" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="215.9" y="-154.94" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="213.36" y="-154.94" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY4" gate="G$1" x="213.36" y="-165.1" smashed="yes">
<attribute name="VALUE" x="213.36" y="-167.64" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="SUPPLY6" gate="G$1" x="223.52" y="-165.1" smashed="yes">
<attribute name="VALUE" x="223.52" y="-167.64" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="SUPPLY7" gate="G$1" x="261.62" y="-129.54" smashed="yes">
<attribute name="VALUE" x="261.62" y="-124.46" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="C4" gate="G$1" x="243.84" y="-152.4" smashed="yes" rot="R90">
<attribute name="NAME" x="241.3" y="-152.4" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="246.38" y="-152.4" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="243.84" y="-152.4" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="C6" gate="G$1" x="254" y="-152.4" smashed="yes" rot="R90">
<attribute name="NAME" x="251.46" y="-152.4" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="256.54" y="-152.4" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="254" y="-152.4" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY8" gate="G$1" x="243.84" y="-165.1" smashed="yes">
<attribute name="VALUE" x="243.84" y="-167.64" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="SUPPLY10" gate="G$1" x="254" y="-165.1" smashed="yes">
<attribute name="VALUE" x="254" y="-167.64" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="SUPPLY22" gate="G$1" x="40.64" y="-154.94" smashed="yes" rot="R90">
<attribute name="VALUE" x="43.18" y="-154.94" size="1.778" layer="96" rot="R90" align="top-center"/>
</instance>
<instance part="SUPPLY23" gate="G$1" x="48.26" y="-132.08" smashed="yes" rot="R270">
<attribute name="VALUE" x="53.34" y="-132.08" size="1.778" layer="96" rot="R270" align="top-center"/>
</instance>
<instance part="R8" gate="G$1" x="-53.34" y="-152.4" smashed="yes" rot="R90">
<attribute name="NAME" x="-55.88" y="-152.4" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="-50.8" y="-152.4" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="-53.34" y="-152.4" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY24" gate="G$1" x="-53.34" y="-162.56" smashed="yes">
<attribute name="VALUE" x="-53.34" y="-165.1" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="R9" gate="G$1" x="-25.4" y="-167.64" smashed="yes" rot="R90">
<attribute name="NAME" x="-27.94" y="-167.64" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="-22.86" y="-167.64" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="-25.4" y="-167.64" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY12" gate="G$1" x="284.48" y="-20.32" smashed="yes">
<attribute name="VALUE" x="284.48" y="-22.86" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="C7" gate="G$1" x="302.26" y="-12.7" smashed="yes" rot="R180">
<attribute name="NAME" x="302.26" y="-15.24" size="1.778" layer="95" rot="R180" align="bottom-center"/>
<attribute name="VALUE" x="302.26" y="-10.16" size="1.778" layer="96" rot="R180" align="top-center"/>
<attribute name="LCSC" x="302.26" y="-12.7" size="1.778" layer="96" rot="R180" display="off"/>
</instance>
<instance part="R4" gate="G$1" x="-15.24" y="116.84" smashed="yes" rot="R90">
<attribute name="NAME" x="-17.78" y="116.84" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="-12.7" y="116.84" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="-15.24" y="116.84" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY14" gate="G$1" x="-15.24" y="99.06" smashed="yes">
<attribute name="VALUE" x="-15.113" y="95.885" size="1.778" layer="96" align="bottom-center"/>
</instance>
<instance part="SUPPLY15" gate="G$1" x="-7.62" y="104.14" smashed="yes">
<attribute name="VALUE" x="-7.493" y="100.965" size="1.778" layer="96" align="bottom-center"/>
</instance>
<instance part="SUPPLY16" gate="G$1" x="58.42" y="93.98" smashed="yes">
<attribute name="VALUE" x="58.547" y="90.805" size="1.778" layer="96" align="bottom-center"/>
</instance>
<instance part="SUPPLY18" gate="G$1" x="-43.18" y="99.06" smashed="yes">
<attribute name="VALUE" x="-43.053" y="95.885" size="1.778" layer="96" align="bottom-center"/>
</instance>
<instance part="SUPPLY19" gate="G$1" x="-22.86" y="99.06" smashed="yes">
<attribute name="VALUE" x="-22.733" y="95.885" size="1.778" layer="96" align="bottom-center"/>
</instance>
<instance part="SUPPLY20" gate="G$1" x="76.2" y="93.98" smashed="yes">
<attribute name="VALUE" x="76.327" y="90.805" size="1.778" layer="96" align="bottom-center"/>
</instance>
<instance part="SUPPLY26" gate="G$1" x="86.36" y="93.98" smashed="yes">
<attribute name="VALUE" x="86.487" y="90.805" size="1.778" layer="96" align="bottom-center"/>
</instance>
<instance part="R5" gate="G$1" x="66.04" y="114.3" smashed="yes" rot="R90">
<attribute name="NAME" x="63.5" y="114.3" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="68.58" y="114.3" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="66.04" y="114.3" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY27" gate="G$1" x="66.04" y="93.98" smashed="yes">
<attribute name="VALUE" x="66.167" y="90.805" size="1.778" layer="96" align="bottom-center"/>
</instance>
<instance part="JP1" gate="A" x="182.88" y="-71.12" smashed="yes">
<attribute name="NAME" x="182.88" y="-63.5" size="1.778" layer="95" align="top-center"/>
<attribute name="VALUE" x="182.88" y="-78.74" size="1.778" layer="96" align="bottom-center"/>
<attribute name="LCSC" x="182.88" y="-71.12" size="1.778" layer="96" display="off"/>
</instance>
<instance part="SUPPLY5" gate="G$1" x="157.48" y="-96.52" smashed="yes">
<attribute name="VALUE" x="157.48" y="-99.06" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="J1" gate="A" x="228.6" y="-71.12" smashed="yes">
<attribute name="NAME" x="232.7646" y="-65.8114" size="2.083" layer="95" ratio="6"/>
<attribute name="LCSC" x="228.6" y="-71.12" size="1.778" layer="96" display="off"/>
</instance>
<instance part="S1" gate="G$1" x="170.18" y="2.54" smashed="yes">
<attribute name="NAME" x="167.63991875" y="4.82606875" size="1.270040625" layer="95"/>
<attribute name="VALUE" x="167.38266875" y="-3.81756875" size="1.271509375" layer="96"/>
<attribute name="LCSC" x="170.18" y="2.54" size="1.778" layer="96" display="off"/>
</instance>
<instance part="S2" gate="G$1" x="238.76" y="5.08" smashed="yes">
<attribute name="NAME" x="236.21991875" y="7.36606875" size="1.270040625" layer="95"/>
<attribute name="VALUE" x="235.96266875" y="-1.27756875" size="1.271509375" layer="96"/>
<attribute name="LCSC" x="238.76" y="5.08" size="1.778" layer="96" display="off"/>
</instance>
<instance part="S3" gate="G$1" x="302.26" y="5.08" smashed="yes">
<attribute name="NAME" x="299.71991875" y="7.36606875" size="1.270040625" layer="95"/>
<attribute name="VALUE" x="299.46266875" y="-1.27756875" size="1.271509375" layer="96"/>
<attribute name="LCSC" x="302.26" y="5.08" size="1.778" layer="96" display="off"/>
</instance>
<instance part="D2" gate="G$1" x="38.1" y="-81.28" smashed="yes">
<attribute name="NAME" x="27.94" y="-72.898" size="1.778" layer="95"/>
<attribute name="VALUE" x="27.94" y="-91.44" size="1.778" layer="96"/>
<attribute name="LCSC" x="38.1" y="-81.28" size="1.778" layer="96" display="off"/>
</instance>
<instance part="C8" gate="A" x="147.32" y="-76.2" smashed="yes" rot="R270">
<attribute name="NAME" x="149.3901" y="-77.1952" size="3.48" layer="95" ratio="10" rot="R270"/>
<attribute name="VALUE" x="141.7701" y="-73.5869" size="1.6764" layer="96" font="custom" ratio="10" rot="R270"/>
<attribute name="LCSC" x="147.32" y="-76.2" size="1.778" layer="96" rot="R270" display="off"/>
</instance>
<instance part="Q1" gate="G$1" x="-10.16" y="-78.74" smashed="yes" rot="R270">
<attribute name="VALUE" x="-17.78" y="-69.85" size="1.778" layer="96" rot="R270"/>
<attribute name="NAME" x="-7.62" y="-69.85" size="1.778" layer="95" rot="R270"/>
<attribute name="LCSC" x="-10.16" y="-78.74" size="1.778" layer="96" rot="R270" display="off"/>
</instance>
<instance part="R7" gate="G$1" x="-22.86" y="-68.58" smashed="yes" rot="R90">
<attribute name="NAME" x="-25.4" y="-68.58" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="-20.32" y="-68.58" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="-22.86" y="-68.58" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="R10" gate="G$1" x="0" y="-68.58" smashed="yes" rot="R90">
<attribute name="NAME" x="-2.54" y="-68.58" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="2.54" y="-68.58" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="0" y="-68.58" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="C10" gate="G$1" x="27.94" y="-142.24" smashed="yes" rot="R90">
<attribute name="NAME" x="25.4" y="-142.24" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="30.48" y="-142.24" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="27.94" y="-142.24" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="JP2" gate="A" x="-88.9" y="-5.08" smashed="yes">
<attribute name="NAME" x="-88.9" y="10.16" size="1.778" layer="95" align="top-center"/>
<attribute name="VALUE" x="-88.9" y="-22.86" size="1.778" layer="96" align="bottom-center"/>
<attribute name="LCSC" x="-88.9" y="-5.08" size="1.778" layer="96" display="off"/>
</instance>
<instance part="JP3" gate="A" x="-63.5" y="-5.08" smashed="yes">
<attribute name="NAME" x="-63.5" y="10.16" size="1.778" layer="95" align="top-center"/>
<attribute name="VALUE" x="-63.5" y="-22.86" size="1.778" layer="96" align="bottom-center"/>
<attribute name="LCSC" x="-63.5" y="-5.08" size="1.778" layer="96" display="off"/>
</instance>
<instance part="FL1" gate="G$1" x="116.84" y="-27.94" smashed="yes" rot="R90">
<attribute name="NAME" x="111.75851875" y="-40.6444" size="2.54148125" layer="95" rot="R90"/>
<attribute name="VALUE" x="121.926640625" y="-40.65" size="2.54331875" layer="96" rot="R90"/>
<attribute name="LCSC" x="116.84" y="-27.94" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="MK1" gate="G$1" x="5.08" y="-144.78" smashed="yes">
<attribute name="NAME" x="-5.1199" y="-128.9701" size="1.78498125" layer="95"/>
<attribute name="VALUE" x="-5.1229" y="-160.0844" size="1.78551875" layer="96"/>
<attribute name="LCSC" x="5.08" y="-144.78" size="1.778" layer="96" display="off"/>
</instance>
<instance part="J3" gate="G$1" x="22.86" y="129.54" smashed="yes">
<attribute name="NAME" x="10.16" y="145.542" size="1.778" layer="95"/>
<attribute name="VALUE" x="10.16" y="110.998" size="1.778" layer="96" rot="MR180"/>
<attribute name="LCSC" x="22.86" y="129.54" size="1.778" layer="96" display="off"/>
</instance>
<instance part="SUPPLY11" gate="G$1" x="-38.1" y="-152.4" smashed="yes">
<attribute name="VALUE" x="-38.1" y="-154.94" size="1.778" layer="96" align="top-center"/>
</instance>
<instance part="R11" gate="G$1" x="-12.7" y="-167.64" smashed="yes" rot="R90">
<attribute name="NAME" x="-15.24" y="-167.64" size="1.778" layer="95" rot="R90" align="bottom-center"/>
<attribute name="VALUE" x="-10.16" y="-167.64" size="1.778" layer="96" rot="R90" align="top-center"/>
<attribute name="LCSC" x="-12.7" y="-167.64" size="1.778" layer="96" rot="R90" display="off"/>
</instance>
<instance part="SUPPLY28" gate="G$1" x="-12.7" y="-182.88" smashed="yes">
<attribute name="VALUE" x="-12.7" y="-185.42" size="1.778" layer="96" align="top-center"/>
</instance>
</instances>
<busses>
</busses>
<nets>
<net name="GND" class="4">
<segment>
<wire x1="5.08" y1="-30.48" x2="12.7" y2="-30.48" width="0.1524" layer="91"/>
<pinref part="SUPPLY17" gate="G$1" pin="GND"/>
<pinref part="U1" gate="G$1" pin="GND"/>
</segment>
<segment>
<wire x1="50.8" y1="20.32" x2="50.8" y2="17.78" width="0.1524" layer="91"/>
<pinref part="C5" gate="G$1" pin="1"/>
<wire x1="50.8" y1="17.78" x2="50.8" y2="2.54" width="0.1524" layer="91"/>
<wire x1="50.8" y1="2.54" x2="63.5" y2="2.54" width="0.1524" layer="91"/>
<wire x1="63.5" y1="2.54" x2="63.5" y2="17.78" width="0.1524" layer="91"/>
<pinref part="C9" gate="G$1" pin="1"/>
<wire x1="50.8" y1="2.54" x2="50.8" y2="-7.62" width="0.1524" layer="91"/>
<junction x="50.8" y="17.78"/>
<junction x="50.8" y="2.54"/>
<pinref part="SUPPLY1" gate="G$1" pin="GND"/>
</segment>
<segment>
<pinref part="C12" gate="G$1" pin="1"/>
<wire x1="93.98" y1="5.08" x2="93.98" y2="0" width="0.1524" layer="91"/>
<pinref part="SUPPLY9" gate="G$1" pin="GND"/>
</segment>
<segment>
<wire x1="53.34" y1="-86.36" x2="60.96" y2="-86.36" width="0.1524" layer="91"/>
<pinref part="SUPPLY13" gate="G$1" pin="GND"/>
<pinref part="D2" gate="G$1" pin="GND"/>
</segment>
<segment>
<wire x1="208.28" y1="78.74" x2="210.82" y2="78.74" width="0.1524" layer="91"/>
<pinref part="SUPPLY21" gate="G$1" pin="GND"/>
<pinref part="U2" gate="G$1" pin="GND"/>
</segment>
<segment>
<pinref part="C18" gate="G$1" pin="1"/>
<wire x1="167.64" y1="73.66" x2="167.64" y2="63.5" width="0.1524" layer="91"/>
<wire x1="167.64" y1="63.5" x2="154.94" y2="63.5" width="0.1524" layer="91"/>
<wire x1="154.94" y1="63.5" x2="154.94" y2="58.42" width="0.1524" layer="91"/>
<pinref part="C17" gate="G$1" pin="1"/>
<wire x1="154.94" y1="73.66" x2="154.94" y2="63.5" width="0.1524" layer="91"/>
<pinref part="SUPPLY25" gate="G$1" pin="GND"/>
<junction x="154.94" y="63.5"/>
</segment>
<segment>
<pinref part="C20" gate="G$1" pin="1"/>
<wire x1="238.76" y1="73.66" x2="238.76" y2="63.5" width="0.1524" layer="91"/>
<pinref part="C19" gate="G$1" pin="1"/>
<wire x1="238.76" y1="63.5" x2="238.76" y2="55.88" width="0.1524" layer="91"/>
<wire x1="226.06" y1="73.66" x2="226.06" y2="63.5" width="0.1524" layer="91"/>
<wire x1="226.06" y1="63.5" x2="238.76" y2="63.5" width="0.1524" layer="91"/>
<pinref part="SUPPLY29" gate="G$1" pin="GND"/>
<junction x="238.76" y="63.5"/>
</segment>
<segment>
<pinref part="D18" gate="G$1" pin="C"/>
<wire x1="266.7" y1="76.2" x2="266.7" y2="55.88" width="0.1524" layer="91"/>
<pinref part="SUPPLY33" gate="G$1" pin="GND"/>
</segment>
<segment>
<wire x1="154.94" y1="2.54" x2="162.56" y2="2.54" width="0.1524" layer="91"/>
<wire x1="154.94" y1="2.54" x2="154.94" y2="-15.24" width="0.1524" layer="91"/>
<pinref part="SUPPLY34" gate="G$1" pin="GND"/>
<pinref part="C21" gate="G$1" pin="2"/>
<wire x1="154.94" y1="-15.24" x2="154.94" y2="-20.32" width="0.1524" layer="91"/>
<wire x1="167.64" y1="-15.24" x2="154.94" y2="-15.24" width="0.1524" layer="91"/>
<junction x="154.94" y="-15.24"/>
<pinref part="S1" gate="G$1" pin="1"/>
</segment>
<segment>
<wire x1="231.14" y1="5.08" x2="220.98" y2="5.08" width="0.1524" layer="91"/>
<wire x1="220.98" y1="5.08" x2="220.98" y2="-12.7" width="0.1524" layer="91"/>
<pinref part="SUPPLY35" gate="G$1" pin="GND"/>
<wire x1="220.98" y1="-12.7" x2="220.98" y2="-17.78" width="0.1524" layer="91"/>
<wire x1="220.98" y1="-12.7" x2="236.22" y2="-12.7" width="0.1524" layer="91"/>
<pinref part="C22" gate="G$1" pin="2"/>
<junction x="220.98" y="-12.7"/>
<pinref part="S2" gate="G$1" pin="1"/>
</segment>
<segment>
<pinref part="U3" gate="G$1" pin="GND"/>
<wire x1="200.66" y1="-162.56" x2="203.2" y2="-162.56" width="0.1524" layer="91"/>
<wire x1="203.2" y1="-162.56" x2="203.2" y2="-172.72" width="0.1524" layer="91"/>
<pinref part="SUPPLY3" gate="G$1" pin="GND"/>
<pinref part="U3" gate="G$1" pin="EP"/>
<wire x1="200.66" y1="-160.02" x2="203.2" y2="-160.02" width="0.1524" layer="91"/>
<wire x1="203.2" y1="-160.02" x2="203.2" y2="-162.56" width="0.1524" layer="91"/>
<junction x="203.2" y="-162.56"/>
</segment>
<segment>
<pinref part="C3" gate="G$1" pin="1"/>
<wire x1="213.36" y1="-157.48" x2="213.36" y2="-162.56" width="0.1524" layer="91"/>
<pinref part="SUPPLY4" gate="G$1" pin="GND"/>
</segment>
<segment>
<pinref part="C2" gate="G$1" pin="1"/>
<wire x1="223.52" y1="-157.48" x2="223.52" y2="-162.56" width="0.1524" layer="91"/>
<pinref part="SUPPLY6" gate="G$1" pin="GND"/>
</segment>
<segment>
<pinref part="C4" gate="G$1" pin="1"/>
<wire x1="243.84" y1="-154.94" x2="243.84" y2="-162.56" width="0.1524" layer="91"/>
<pinref part="SUPPLY8" gate="G$1" pin="GND"/>
</segment>
<segment>
<pinref part="C6" gate="G$1" pin="1"/>
<wire x1="254" y1="-154.94" x2="254" y2="-162.56" width="0.1524" layer="91"/>
<pinref part="SUPPLY10" gate="G$1" pin="GND"/>
</segment>
<segment>
<wire x1="20.32" y1="-154.94" x2="27.94" y2="-154.94" width="0.1524" layer="91"/>
<pinref part="SUPPLY22" gate="G$1" pin="GND"/>
<pinref part="C10" gate="G$1" pin="1"/>
<wire x1="27.94" y1="-154.94" x2="38.1" y2="-154.94" width="0.1524" layer="91"/>
<wire x1="27.94" y1="-144.78" x2="27.94" y2="-154.94" width="0.1524" layer="91"/>
<junction x="27.94" y="-154.94"/>
<pinref part="MK1" gate="G$1" pin="GND"/>
</segment>
<segment>
<pinref part="SUPPLY24" gate="G$1" pin="GND"/>
<wire x1="-53.34" y1="-160.02" x2="-53.34" y2="-157.48" width="0.1524" layer="91"/>
<pinref part="R8" gate="G$1" pin="1"/>
</segment>
<segment>
<wire x1="294.64" y1="5.08" x2="284.48" y2="5.08" width="0.1524" layer="91"/>
<wire x1="284.48" y1="5.08" x2="284.48" y2="-12.7" width="0.1524" layer="91"/>
<pinref part="SUPPLY12" gate="G$1" pin="GND"/>
<wire x1="284.48" y1="-12.7" x2="284.48" y2="-17.78" width="0.1524" layer="91"/>
<wire x1="284.48" y1="-12.7" x2="299.72" y2="-12.7" width="0.1524" layer="91"/>
<pinref part="C7" gate="G$1" pin="2"/>
<junction x="284.48" y="-12.7"/>
<pinref part="S3" gate="G$1" pin="1"/>
</segment>
<segment>
<pinref part="R4" gate="G$1" pin="1"/>
<wire x1="-15.24" y1="111.76" x2="-15.24" y2="101.6" width="0.1524" layer="91"/>
<pinref part="SUPPLY14" gate="G$1" pin="GND"/>
</segment>
<segment>
<wire x1="5.08" y1="119.38" x2="-7.62" y2="119.38" width="0.1524" layer="91"/>
<wire x1="-7.62" y1="119.38" x2="-7.62" y2="114.3" width="0.1524" layer="91"/>
<wire x1="-7.62" y1="114.3" x2="-7.62" y2="106.68" width="0.1524" layer="91"/>
<wire x1="5.08" y1="114.3" x2="-7.62" y2="114.3" width="0.1524" layer="91"/>
<pinref part="SUPPLY15" gate="G$1" pin="GND"/>
<pinref part="J3" gate="G$1" pin="SHIELD"/>
<junction x="-7.62" y="114.3"/>
<pinref part="J3" gate="G$1" pin="GND_A"/>
</segment>
<segment>
<wire x1="40.64" y1="119.38" x2="58.42" y2="119.38" width="0.1524" layer="91"/>
<wire x1="58.42" y1="119.38" x2="58.42" y2="96.52" width="0.1524" layer="91"/>
<pinref part="SUPPLY16" gate="G$1" pin="GND"/>
<pinref part="J3" gate="G$1" pin="GND_B"/>
</segment>
<segment>
<pinref part="C1" gate="G$1" pin="2"/>
<wire x1="-43.18" y1="129.54" x2="-43.18" y2="101.6" width="0.1524" layer="91"/>
<pinref part="SUPPLY18" gate="G$1" pin="GND"/>
</segment>
<segment>
<wire x1="-22.86" y1="116.84" x2="-22.86" y2="101.6" width="0.1524" layer="91"/>
<pinref part="SUPPLY19" gate="G$1" pin="GND"/>
<pinref part="D1" gate="G$1" pin="C"/>
</segment>
<segment>
<wire x1="76.2" y1="109.22" x2="76.2" y2="96.52" width="0.1524" layer="91"/>
<pinref part="SUPPLY20" gate="G$1" pin="GND"/>
<pinref part="D9" gate="G$1" pin="C"/>
</segment>
<segment>
<pinref part="R5" gate="G$1" pin="1"/>
<wire x1="66.04" y1="109.22" x2="66.04" y2="96.52" width="0.1524" layer="91"/>
<pinref part="SUPPLY27" gate="G$1" pin="GND"/>
</segment>
<segment>
<wire x1="177.8" y1="-73.66" x2="157.48" y2="-73.66" width="0.1524" layer="91"/>
<wire x1="157.48" y1="-73.66" x2="157.48" y2="-86.36" width="0.1524" layer="91"/>
<pinref part="SUPPLY5" gate="G$1" pin="GND"/>
<wire x1="157.48" y1="-86.36" x2="157.48" y2="-93.98" width="0.1524" layer="91"/>
<wire x1="147.32" y1="-86.36" x2="157.48" y2="-86.36" width="0.1524" layer="91"/>
<junction x="157.48" y="-86.36"/>
<pinref part="C8" gate="A" pin="2"/>
<wire x1="147.32" y1="-83.82" x2="147.32" y2="-86.36" width="0.1524" layer="91"/>
<pinref part="JP1" gate="A" pin="3"/>
</segment>
<segment>
<pinref part="SUPPLY11" gate="G$1" pin="GND"/>
<wire x1="-38.1" y1="-149.86" x2="-38.1" y2="-139.7" width="0.1524" layer="91"/>
<wire x1="-10.16" y1="-139.7" x2="-38.1" y2="-139.7" width="0.1524" layer="91"/>
<pinref part="MK1" gate="G$1" pin="CONFIG"/>
</segment>
<segment>
<pinref part="R11" gate="G$1" pin="1"/>
<wire x1="-12.7" y1="-172.72" x2="-12.7" y2="-180.34" width="0.1524" layer="91"/>
<pinref part="SUPPLY28" gate="G$1" pin="GND"/>
</segment>
</net>
<net name="GPIO19" class="4">
<segment>
<wire x1="5.08" y1="10.16" x2="20.32" y2="10.16" width="0.1524" layer="91"/>
<label x="12.7" y="10.16" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO19"/>
</segment>
<segment>
<wire x1="40.64" y1="132.08" x2="58.42" y2="132.08" width="0.1524" layer="91"/>
<wire x1="58.42" y1="132.08" x2="86.36" y2="132.08" width="0.1524" layer="91"/>
<wire x1="86.36" y1="132.08" x2="86.36" y2="119.38" width="0.1524" layer="91"/>
<wire x1="5.08" y1="129.54" x2="-10.16" y2="129.54" width="0.1524" layer="91"/>
<wire x1="-10.16" y1="129.54" x2="-10.16" y2="154.94" width="0.1524" layer="91"/>
<wire x1="-10.16" y1="154.94" x2="58.42" y2="154.94" width="0.1524" layer="91"/>
<wire x1="58.42" y1="154.94" x2="58.42" y2="132.08" width="0.1524" layer="91"/>
<wire x1="86.36" y1="132.08" x2="99.06" y2="132.08" width="0.1524" layer="91"/>
<label x="91.44" y="132.08" size="1.778" layer="95"/>
<pinref part="J3" gate="G$1" pin="D1-"/>
<junction x="58.42" y="132.08"/>
<junction x="86.36" y="132.08"/>
<pinref part="J3" gate="G$1" pin="D2-"/>
<pinref part="D5" gate="G$1" pin="A"/>
</segment>
</net>
<net name="GPIO20" class="4">
<segment>
<wire x1="5.08" y1="7.62" x2="20.32" y2="7.62" width="0.1524" layer="91"/>
<label x="12.7" y="7.62" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO20"/>
</segment>
<segment>
<wire x1="40.64" y1="129.54" x2="55.88" y2="129.54" width="0.1524" layer="91"/>
<wire x1="55.88" y1="129.54" x2="76.2" y2="129.54" width="0.1524" layer="91"/>
<wire x1="76.2" y1="129.54" x2="76.2" y2="119.38" width="0.1524" layer="91"/>
<wire x1="-7.62" y1="132.08" x2="-7.62" y2="152.4" width="0.1524" layer="91"/>
<wire x1="-7.62" y1="152.4" x2="55.88" y2="152.4" width="0.1524" layer="91"/>
<wire x1="55.88" y1="152.4" x2="55.88" y2="129.54" width="0.1524" layer="91"/>
<wire x1="76.2" y1="129.54" x2="99.06" y2="129.54" width="0.1524" layer="91"/>
<label x="91.44" y="129.54" size="1.778" layer="95"/>
<wire x1="5.08" y1="132.08" x2="-7.62" y2="132.08" width="0.1524" layer="91"/>
<pinref part="J3" gate="G$1" pin="D1+"/>
<junction x="55.88" y="129.54"/>
<junction x="76.2" y="129.54"/>
<pinref part="J3" gate="G$1" pin="D2+"/>
<pinref part="D9" gate="G$1" pin="A"/>
</segment>
</net>
<net name="U0RXD" class="4">
<segment>
<wire x1="-25.4" y1="22.86" x2="-40.64" y2="22.86" width="0.1524" layer="91"/>
<label x="-40.64" y="22.86" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="RXD0"/>
</segment>
<segment>
<wire x1="-93.98" y1="2.54" x2="-106.68" y2="2.54" width="0.1524" layer="91"/>
<label x="-106.68" y="2.54" size="1.778" layer="95"/>
<pinref part="JP2" gate="A" pin="2"/>
</segment>
</net>
<net name="U0TXD" class="4">
<segment>
<wire x1="-25.4" y1="20.32" x2="-40.64" y2="20.32" width="0.1524" layer="91"/>
<label x="-40.64" y="20.32" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="TXD0"/>
</segment>
<segment>
<wire x1="-93.98" y1="0" x2="-106.68" y2="0" width="0.1524" layer="91"/>
<label x="-106.68" y="0" size="1.778" layer="95"/>
<pinref part="JP2" gate="A" pin="3"/>
</segment>
</net>
<net name="VCC_3V3" class="2">
<segment>
<wire x1="50.8" y1="30.48" x2="50.8" y2="22.86" width="0.1524" layer="91"/>
<pinref part="C5" gate="G$1" pin="2"/>
<wire x1="50.8" y1="30.48" x2="63.5" y2="30.48" width="0.1524" layer="91"/>
<wire x1="63.5" y1="30.48" x2="63.5" y2="22.86" width="0.1524" layer="91"/>
<pinref part="C9" gate="G$1" pin="2"/>
<wire x1="63.5" y1="30.48" x2="63.5" y2="45.72" width="0.1524" layer="91"/>
<label x="63.5" y="35.56" size="1.778" layer="95" rot="R90"/>
<wire x1="43.18" y1="30.48" x2="50.8" y2="30.48" width="0.1524" layer="91"/>
<junction x="50.8" y="30.48"/>
<junction x="63.5" y="30.48"/>
<pinref part="FL3" gate="G$1" pin="2"/>
</segment>
<segment>
<wire x1="208.28" y1="88.9" x2="226.06" y2="88.9" width="0.1524" layer="91"/>
<wire x1="226.06" y1="88.9" x2="238.76" y2="88.9" width="0.1524" layer="91"/>
<wire x1="226.06" y1="88.9" x2="226.06" y2="78.74" width="0.1524" layer="91"/>
<pinref part="C19" gate="G$1" pin="2"/>
<wire x1="238.76" y1="88.9" x2="238.76" y2="78.74" width="0.1524" layer="91"/>
<pinref part="C20" gate="G$1" pin="2"/>
<wire x1="238.76" y1="88.9" x2="238.76" y2="106.68" width="0.1524" layer="91"/>
<label x="238.76" y="106.68" size="1.778" layer="95"/>
<wire x1="238.76" y1="88.9" x2="251.46" y2="88.9" width="0.1524" layer="91"/>
<pinref part="R2" gate="G$1" pin="1"/>
<junction x="226.06" y="88.9"/>
<junction x="238.76" y="88.9"/>
<pinref part="U2" gate="G$1" pin="VOUT"/>
</segment>
<segment>
<pinref part="R7" gate="G$1" pin="2"/>
<wire x1="-22.86" y1="-63.5" x2="-35.56" y2="-63.5" width="0.1524" layer="91"/>
<pinref part="Q1" gate="G$1" pin="G"/>
<wire x1="-12.7" y1="-76.2" x2="-12.7" y2="-63.5" width="0.1524" layer="91"/>
<wire x1="-12.7" y1="-63.5" x2="-22.86" y2="-63.5" width="0.1524" layer="91"/>
<label x="-35.56" y="-63.5" size="1.778" layer="95"/>
<junction x="-22.86" y="-63.5"/>
</segment>
<segment>
<wire x1="116.84" y1="-15.24" x2="116.84" y2="5.08" width="0.1524" layer="91"/>
<label x="116.84" y="0" size="1.778" layer="95" rot="R90"/>
<pinref part="FL1" gate="G$1" pin="2"/>
</segment>
</net>
<net name="GPIO17" class="4">
<segment>
<wire x1="5.08" y1="15.24" x2="20.32" y2="15.24" width="0.1524" layer="91"/>
<label x="12.7" y="15.24" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO17"/>
</segment>
</net>
<net name="GPIO18" class="4">
<segment>
<wire x1="5.08" y1="12.7" x2="20.32" y2="12.7" width="0.1524" layer="91"/>
<label x="12.7" y="12.7" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO18"/>
</segment>
</net>
<net name="GPIO21" class="4">
<segment>
<wire x1="5.08" y1="5.08" x2="20.32" y2="5.08" width="0.1524" layer="91"/>
<label x="12.7" y="5.08" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO21"/>
</segment>
</net>
<net name="GPIO35" class="4">
<segment>
<wire x1="5.08" y1="2.54" x2="20.32" y2="2.54" width="0.1524" layer="91"/>
<label x="12.7" y="2.54" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO35"/>
</segment>
</net>
<net name="GPIO36" class="4">
<segment>
<wire x1="5.08" y1="0" x2="20.32" y2="0" width="0.1524" layer="91"/>
<label x="12.7" y="0" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO36"/>
</segment>
</net>
<net name="GPIO37" class="4">
<segment>
<wire x1="5.08" y1="-2.54" x2="20.32" y2="-2.54" width="0.1524" layer="91"/>
<label x="12.7" y="-2.54" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO37"/>
</segment>
</net>
<net name="GPIO38" class="4">
<segment>
<wire x1="5.08" y1="-5.08" x2="20.32" y2="-5.08" width="0.1524" layer="91"/>
<label x="12.7" y="-5.08" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO38"/>
</segment>
<segment>
<wire x1="-40.64" y1="-81.28" x2="-22.86" y2="-81.28" width="0.1524" layer="91"/>
<label x="-40.64" y="-81.28" size="1.778" layer="95"/>
<wire x1="-22.86" y1="-81.28" x2="-22.86" y2="-73.66" width="0.1524" layer="91"/>
<pinref part="R7" gate="G$1" pin="1"/>
<wire x1="-22.86" y1="-81.28" x2="-15.24" y2="-81.28" width="0.1524" layer="91"/>
<junction x="-22.86" y="-81.28"/>
<pinref part="Q1" gate="G$1" pin="S"/>
</segment>
</net>
<net name="GPIO39" class="4">
<segment>
<wire x1="5.08" y1="-7.62" x2="20.32" y2="-7.62" width="0.1524" layer="91"/>
<label x="12.7" y="-7.62" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO39"/>
</segment>
</net>
<net name="GPIO40" class="4">
<segment>
<wire x1="5.08" y1="-10.16" x2="20.32" y2="-10.16" width="0.1524" layer="91"/>
<label x="12.7" y="-10.16" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO40"/>
</segment>
</net>
<net name="GPIO41" class="4">
<segment>
<wire x1="5.08" y1="-12.7" x2="20.32" y2="-12.7" width="0.1524" layer="91"/>
<label x="12.7" y="-12.7" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO41"/>
</segment>
</net>
<net name="GPIO42" class="4">
<segment>
<wire x1="5.08" y1="-15.24" x2="20.32" y2="-15.24" width="0.1524" layer="91"/>
<label x="12.7" y="-15.24" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO42"/>
</segment>
</net>
<net name="GPIO45" class="4">
<segment>
<wire x1="5.08" y1="-17.78" x2="20.32" y2="-17.78" width="0.1524" layer="91"/>
<label x="12.7" y="-17.78" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO45"/>
</segment>
</net>
<net name="GPIO46" class="4">
<segment>
<wire x1="5.08" y1="-20.32" x2="20.32" y2="-20.32" width="0.1524" layer="91"/>
<label x="12.7" y="-20.32" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO46"/>
</segment>
</net>
<net name="GPIO47" class="4">
<segment>
<wire x1="5.08" y1="-22.86" x2="20.32" y2="-22.86" width="0.1524" layer="91"/>
<label x="12.7" y="-22.86" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO47"/>
</segment>
</net>
<net name="GPIO48" class="4">
<segment>
<wire x1="5.08" y1="-25.4" x2="20.32" y2="-25.4" width="0.1524" layer="91"/>
<label x="12.7" y="-25.4" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO48"/>
</segment>
</net>
<net name="GPIO0" class="4">
<segment>
<pinref part="C21" gate="G$1" pin="1"/>
<wire x1="172.72" y1="-15.24" x2="182.88" y2="-15.24" width="0.1524" layer="91"/>
<wire x1="182.88" y1="-15.24" x2="182.88" y2="2.54" width="0.1524" layer="91"/>
<label x="198.12" y="2.54" size="1.778" layer="95"/>
<junction x="182.88" y="2.54"/>
<wire x1="182.88" y1="2.54" x2="203.2" y2="2.54" width="0.1524" layer="91"/>
<pinref part="S1" gate="G$1" pin="3"/>
<wire x1="177.8" y1="2.54" x2="182.88" y2="2.54" width="0.1524" layer="91"/>
</segment>
<segment>
<wire x1="-25.4" y1="15.24" x2="-40.64" y2="15.24" width="0.1524" layer="91"/>
<label x="-40.64" y="15.24" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO0"/>
</segment>
<segment>
<pinref part="R6" gate="G$1" pin="1"/>
<wire x1="68.58" y1="-25.4" x2="68.58" y2="-33.02" width="0.1524" layer="91"/>
<label x="68.58" y="-33.02" size="1.778" layer="95"/>
</segment>
<segment>
<wire x1="-93.98" y1="-2.54" x2="-106.68" y2="-2.54" width="0.1524" layer="91"/>
<label x="-106.68" y="-2.54" size="1.778" layer="95"/>
<pinref part="JP2" gate="A" pin="4"/>
</segment>
</net>
<net name="GPIO2" class="4">
<segment>
<wire x1="-40.64" y1="10.16" x2="-25.4" y2="10.16" width="0.1524" layer="91"/>
<label x="-40.64" y="10.16" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO2"/>
</segment>
<segment>
<pinref part="C7" gate="G$1" pin="1"/>
<wire x1="304.8" y1="-12.7" x2="320.04" y2="-12.7" width="0.1524" layer="91"/>
<wire x1="320.04" y1="-12.7" x2="320.04" y2="5.08" width="0.1524" layer="91"/>
<wire x1="320.04" y1="5.08" x2="309.88" y2="5.08" width="0.1524" layer="91"/>
<wire x1="320.04" y1="5.08" x2="332.74" y2="5.08" width="0.1524" layer="91"/>
<junction x="320.04" y="5.08"/>
<label x="325.12" y="5.08" size="1.778" layer="95"/>
<pinref part="S3" gate="G$1" pin="3"/>
</segment>
<segment>
<wire x1="-93.98" y1="-7.62" x2="-106.68" y2="-7.62" width="0.1524" layer="91"/>
<label x="-106.68" y="-7.62" size="1.778" layer="95"/>
<pinref part="JP2" gate="A" pin="6"/>
</segment>
</net>
<net name="GPIO3" class="4">
<segment>
<wire x1="-40.64" y1="7.62" x2="-25.4" y2="7.62" width="0.1524" layer="91"/>
<label x="-40.64" y="7.62" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO3"/>
</segment>
<segment>
<wire x1="177.8" y1="-68.58" x2="157.48" y2="-68.58" width="0.1524" layer="91"/>
<label x="157.48" y="-68.58" size="1.778" layer="95"/>
<pinref part="JP1" gate="A" pin="1"/>
</segment>
<segment>
<wire x1="-93.98" y1="-10.16" x2="-106.68" y2="-10.16" width="0.1524" layer="91"/>
<label x="-106.68" y="-10.16" size="1.778" layer="95"/>
<pinref part="JP2" gate="A" pin="7"/>
</segment>
</net>
<net name="GPIO4" class="4">
<segment>
<wire x1="-40.64" y1="5.08" x2="-25.4" y2="5.08" width="0.1524" layer="91"/>
<label x="-40.64" y="5.08" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO4"/>
</segment>
<segment>
<wire x1="-93.98" y1="-12.7" x2="-106.68" y2="-12.7" width="0.1524" layer="91"/>
<label x="-106.68" y="-12.7" size="1.778" layer="95"/>
<pinref part="JP2" gate="A" pin="8"/>
</segment>
</net>
<net name="GPIO5" class="4">
<segment>
<wire x1="-40.64" y1="2.54" x2="-25.4" y2="2.54" width="0.1524" layer="91"/>
<label x="-40.64" y="2.54" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO5"/>
</segment>
<segment>
<wire x1="-93.98" y1="-15.24" x2="-106.68" y2="-15.24" width="0.1524" layer="91"/>
<label x="-106.68" y="-15.24" size="1.778" layer="95"/>
<pinref part="JP2" gate="A" pin="9"/>
</segment>
</net>
<net name="GPIO6" class="4">
<segment>
<wire x1="-40.64" y1="0" x2="-25.4" y2="0" width="0.1524" layer="91"/>
<label x="-40.64" y="0" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO6"/>
</segment>
<segment>
<wire x1="-93.98" y1="-17.78" x2="-106.68" y2="-17.78" width="0.1524" layer="91"/>
<label x="-106.68" y="-17.78" size="1.778" layer="95"/>
<pinref part="JP2" gate="A" pin="10"/>
</segment>
</net>
<net name="GPIO8" class="4">
<segment>
<wire x1="-40.64" y1="-5.08" x2="-25.4" y2="-5.08" width="0.1524" layer="91"/>
<label x="-40.64" y="-5.08" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO8"/>
</segment>
<segment>
<wire x1="-68.58" y1="2.54" x2="-81.28" y2="2.54" width="0.1524" layer="91"/>
<label x="-81.28" y="2.54" size="1.778" layer="95"/>
<pinref part="JP3" gate="A" pin="2"/>
</segment>
<segment>
<pinref part="U3" gate="G$1" pin="GAIN_SLOT"/>
<wire x1="165.1" y1="-147.32" x2="147.32" y2="-147.32" width="0.1524" layer="91"/>
<label x="147.32" y="-147.32" size="1.778" layer="95"/>
</segment>
</net>
<net name="GPIO9" class="4">
<segment>
<wire x1="-40.64" y1="-7.62" x2="-25.4" y2="-7.62" width="0.1524" layer="91"/>
<label x="-40.64" y="-7.62" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO9"/>
</segment>
<segment>
<wire x1="-68.58" y1="0" x2="-81.28" y2="0" width="0.1524" layer="91"/>
<label x="-81.28" y="0" size="1.778" layer="95"/>
<pinref part="JP3" gate="A" pin="3"/>
</segment>
</net>
<net name="GPIO10" class="4">
<segment>
<wire x1="-40.64" y1="-10.16" x2="-25.4" y2="-10.16" width="0.1524" layer="91"/>
<label x="-40.64" y="-10.16" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO10"/>
</segment>
<segment>
<wire x1="-68.58" y1="-2.54" x2="-81.28" y2="-2.54" width="0.1524" layer="91"/>
<label x="-81.28" y="-2.54" size="1.778" layer="95"/>
<pinref part="JP3" gate="A" pin="4"/>
</segment>
</net>
<net name="GPIO11" class="4">
<segment>
<wire x1="-40.64" y1="-12.7" x2="-25.4" y2="-12.7" width="0.1524" layer="91"/>
<label x="-40.64" y="-12.7" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO11"/>
</segment>
<segment>
<wire x1="-68.58" y1="-5.08" x2="-81.28" y2="-5.08" width="0.1524" layer="91"/>
<label x="-81.28" y="-5.08" size="1.778" layer="95"/>
<pinref part="JP3" gate="A" pin="5"/>
</segment>
</net>
<net name="GPIO15" class="4">
<segment>
<wire x1="-40.64" y1="-22.86" x2="-25.4" y2="-22.86" width="0.1524" layer="91"/>
<label x="-40.64" y="-22.86" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO15"/>
</segment>
<segment>
<wire x1="-68.58" y1="-15.24" x2="-81.28" y2="-15.24" width="0.1524" layer="91"/>
<label x="-81.28" y="-15.24" size="1.778" layer="95"/>
<pinref part="JP3" gate="A" pin="9"/>
</segment>
</net>
<net name="GPIO16" class="4">
<segment>
<wire x1="-40.64" y1="-25.4" x2="-25.4" y2="-25.4" width="0.1524" layer="91"/>
<label x="-40.64" y="-25.4" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO16"/>
</segment>
<segment>
<wire x1="-68.58" y1="-17.78" x2="-81.28" y2="-17.78" width="0.1524" layer="91"/>
<label x="-81.28" y="-17.78" size="1.778" layer="95"/>
<pinref part="JP3" gate="A" pin="10"/>
</segment>
</net>
<net name="ESP_3V3" class="4">
<segment>
<wire x1="12.7" y1="43.18" x2="12.7" y2="30.48" width="0.1524" layer="91"/>
<wire x1="5.08" y1="30.48" x2="12.7" y2="30.48" width="0.1524" layer="91"/>
<label x="10.16" y="33.02" size="1.778" layer="95" rot="R90"/>
<wire x1="12.7" y1="30.48" x2="15.24" y2="30.48" width="0.1524" layer="91"/>
<junction x="12.7" y="30.48"/>
<pinref part="FL3" gate="G$1" pin="1"/>
<pinref part="U1" gate="G$1" pin="3V3"/>
</segment>
<segment>
<pinref part="R1" gate="G$1" pin="2"/>
<wire x1="93.98" y1="35.56" x2="93.98" y2="43.18" width="0.1524" layer="91"/>
<label x="93.98" y="43.18" size="1.778" layer="95"/>
</segment>
<segment>
<pinref part="R6" gate="G$1" pin="2"/>
<wire x1="68.58" y1="-15.24" x2="68.58" y2="-10.16" width="0.1524" layer="91"/>
<label x="68.58" y="-10.16" size="1.778" layer="95"/>
</segment>
</net>
<net name="VCC_5V" class="2">
<segment>
<wire x1="182.88" y1="88.9" x2="177.8" y2="88.9" width="0.1524" layer="91"/>
<wire x1="177.8" y1="88.9" x2="167.64" y2="88.9" width="0.1524" layer="91"/>
<wire x1="167.64" y1="88.9" x2="167.64" y2="78.74" width="0.1524" layer="91"/>
<pinref part="C18" gate="G$1" pin="2"/>
<wire x1="167.64" y1="88.9" x2="154.94" y2="88.9" width="0.1524" layer="91"/>
<wire x1="154.94" y1="88.9" x2="154.94" y2="78.74" width="0.1524" layer="91"/>
<pinref part="C17" gate="G$1" pin="2"/>
<wire x1="154.94" y1="88.9" x2="154.94" y2="96.52" width="0.1524" layer="91"/>
<label x="154.94" y="96.52" size="1.778" layer="95"/>
<wire x1="177.8" y1="88.9" x2="177.8" y2="83.82" width="0.1524" layer="91"/>
<wire x1="177.8" y1="83.82" x2="182.88" y2="83.82" width="0.1524" layer="91"/>
<junction x="177.8" y="88.9"/>
<junction x="167.64" y="88.9"/>
<junction x="154.94" y="88.9"/>
<pinref part="U2" gate="G$1" pin="VIN"/>
<pinref part="U2" gate="G$1" pin="EN"/>
</segment>
<segment>
<wire x1="-40.64" y1="142.24" x2="-43.18" y2="142.24" width="0.1524" layer="91"/>
<wire x1="-43.18" y1="142.24" x2="-43.18" y2="137.16" width="0.1524" layer="91"/>
<pinref part="C1" gate="G$1" pin="1"/>
<wire x1="-43.18" y1="142.24" x2="-43.18" y2="152.4" width="0.1524" layer="91"/>
<junction x="-43.18" y="142.24"/>
<label x="-43.18" y="152.4" size="1.778" layer="95"/>
<pinref part="D13" gate="G$1" pin="K"/>
</segment>
<segment>
<wire x1="53.34" y1="-76.2" x2="73.66" y2="-76.2" width="0.1524" layer="91"/>
<label x="66.04" y="-76.2" size="1.778" layer="95"/>
<pinref part="D2" gate="G$1" pin="VDD"/>
</segment>
<segment>
<wire x1="177.8" y1="-71.12" x2="147.32" y2="-71.12" width="0.1524" layer="91"/>
<label x="134.62" y="-71.12" size="1.778" layer="95"/>
<pinref part="C8" gate="A" pin="1"/>
<wire x1="147.32" y1="-71.12" x2="137.16" y2="-71.12" width="0.1524" layer="91"/>
<wire x1="147.32" y1="-76.2" x2="147.32" y2="-71.12" width="0.1524" layer="91"/>
<junction x="147.32" y="-71.12"/>
<pinref part="JP1" gate="A" pin="2"/>
</segment>
<segment>
<pinref part="R10" gate="G$1" pin="2"/>
<wire x1="0" y1="-63.5" x2="7.62" y2="-63.5" width="0.1524" layer="91"/>
<label x="2.54" y="-63.5" size="1.778" layer="95"/>
</segment>
</net>
<net name="CHIP_PU" class="4">
<segment>
<pinref part="R1" gate="G$1" pin="1"/>
<wire x1="93.98" y1="25.4" x2="93.98" y2="17.78" width="0.1524" layer="91"/>
<pinref part="C12" gate="G$1" pin="2"/>
<wire x1="93.98" y1="17.78" x2="93.98" y2="10.16" width="0.1524" layer="91"/>
<wire x1="93.98" y1="17.78" x2="81.28" y2="17.78" width="0.1524" layer="91"/>
<junction x="93.98" y="17.78"/>
<label x="78.74" y="17.78" size="1.778" layer="95"/>
</segment>
<segment>
<wire x1="-25.4" y1="27.94" x2="-40.64" y2="27.94" width="0.1524" layer="91"/>
<label x="-40.64" y="27.94" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="EN"/>
</segment>
<segment>
<pinref part="C22" gate="G$1" pin="1"/>
<wire x1="241.3" y1="-12.7" x2="254" y2="-12.7" width="0.1524" layer="91"/>
<wire x1="254" y1="-12.7" x2="254" y2="5.08" width="0.1524" layer="91"/>
<wire x1="254" y1="5.08" x2="246.38" y2="5.08" width="0.1524" layer="91"/>
<wire x1="254" y1="5.08" x2="269.24" y2="5.08" width="0.1524" layer="91"/>
<junction x="254" y="5.08"/>
<label x="259.08" y="5.08" size="1.778" layer="95"/>
<pinref part="S2" gate="G$1" pin="3"/>
</segment>
<segment>
<wire x1="-93.98" y1="5.08" x2="-106.68" y2="5.08" width="0.1524" layer="91"/>
<label x="-106.68" y="5.08" size="1.778" layer="95"/>
<pinref part="JP2" gate="A" pin="1"/>
</segment>
</net>
<net name="RGB_CTRL" class="4">
<segment>
<wire x1="-5.08" y1="-81.28" x2="0" y2="-81.28" width="0.1524" layer="91"/>
<label x="5.08" y="-81.28" size="1.778" layer="95"/>
<pinref part="D2" gate="G$1" pin="DIN"/>
<pinref part="Q1" gate="G$1" pin="D"/>
<pinref part="R10" gate="G$1" pin="1"/>
<wire x1="0" y1="-81.28" x2="22.86" y2="-81.28" width="0.1524" layer="91"/>
<wire x1="0" y1="-73.66" x2="0" y2="-81.28" width="0.1524" layer="91"/>
<junction x="0" y="-81.28"/>
</segment>
</net>
<net name="N$11" class="4">
<segment>
<pinref part="R2" gate="G$1" pin="2"/>
<wire x1="261.62" y1="88.9" x2="266.7" y2="88.9" width="0.1524" layer="91"/>
<wire x1="266.7" y1="88.9" x2="266.7" y2="81.28" width="0.1524" layer="91"/>
<pinref part="D18" gate="G$1" pin="A"/>
</segment>
</net>
<net name="SD_MODE" class="4">
<segment>
<pinref part="U3" gate="G$1" pin="SD_MODE"/>
<wire x1="165.1" y1="-152.4" x2="162.56" y2="-152.4" width="0.1524" layer="91"/>
<wire x1="162.56" y1="-152.4" x2="147.32" y2="-152.4" width="0.1524" layer="91"/>
<wire x1="162.56" y1="-152.4" x2="162.56" y2="-157.48" width="0.1524" layer="91"/>
<pinref part="R3" gate="G$1" pin="2"/>
<label x="147.32" y="-152.4" size="1.778" layer="95"/>
<junction x="162.56" y="-152.4"/>
</segment>
</net>
<net name="VDD" class="2">
<segment>
<pinref part="R3" gate="G$1" pin="1"/>
<wire x1="162.56" y1="-167.64" x2="162.56" y2="-172.72" width="0.1524" layer="91"/>
<pinref part="SUPPLY2" gate="G$1" pin="VDD"/>
</segment>
<segment>
<pinref part="U3" gate="G$1" pin="VDD"/>
<wire x1="200.66" y1="-137.16" x2="243.84" y2="-137.16" width="0.1524" layer="91"/>
<wire x1="243.84" y1="-137.16" x2="243.84" y2="-149.86" width="0.1524" layer="91"/>
<wire x1="243.84" y1="-137.16" x2="254" y2="-137.16" width="0.1524" layer="91"/>
<wire x1="254" y1="-137.16" x2="254" y2="-149.86" width="0.1524" layer="91"/>
<wire x1="254" y1="-137.16" x2="261.62" y2="-137.16" width="0.1524" layer="91"/>
<wire x1="261.62" y1="-137.16" x2="261.62" y2="-129.54" width="0.1524" layer="91"/>
<pinref part="SUPPLY7" gate="G$1" pin="VDD"/>
<junction x="243.84" y="-137.16"/>
<junction x="254" y="-137.16"/>
<pinref part="C4" gate="G$1" pin="2"/>
<pinref part="C6" gate="G$1" pin="2"/>
</segment>
<segment>
<wire x1="20.32" y1="-132.08" x2="27.94" y2="-132.08" width="0.1524" layer="91"/>
<pinref part="SUPPLY23" gate="G$1" pin="VDD"/>
<pinref part="C10" gate="G$1" pin="2"/>
<wire x1="27.94" y1="-132.08" x2="48.26" y2="-132.08" width="0.1524" layer="91"/>
<wire x1="27.94" y1="-139.7" x2="27.94" y2="-132.08" width="0.1524" layer="91"/>
<junction x="27.94" y="-132.08"/>
<pinref part="MK1" gate="G$1" pin="VDD"/>
</segment>
<segment>
<wire x1="116.84" y1="-43.18" x2="116.84" y2="-60.96" width="0.1524" layer="91"/>
<label x="116.84" y="-60.96" size="1.778" layer="95"/>
<pinref part="FL1" gate="G$1" pin="1"/>
</segment>
</net>
<net name="LRCLK" class="4">
<segment>
<pinref part="U3" gate="G$1" pin="LRCLK"/>
<wire x1="165.1" y1="-149.86" x2="147.32" y2="-149.86" width="0.1524" layer="91"/>
<label x="147.32" y="-149.86" size="1.778" layer="95"/>
</segment>
<segment>
<wire x1="-25.4" y1="-15.24" x2="-40.64" y2="-15.24" width="0.1524" layer="91"/>
<label x="-40.64" y="-15.24" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO12"/>
</segment>
<segment>
<wire x1="-10.16" y1="-149.86" x2="-20.32" y2="-149.86" width="0.1524" layer="91"/>
<label x="-20.32" y="-149.86" size="1.778" layer="95"/>
<pinref part="MK1" gate="G$1" pin="WS"/>
</segment>
<segment>
<wire x1="-68.58" y1="-7.62" x2="-81.28" y2="-7.62" width="0.1524" layer="91"/>
<label x="-81.28" y="-7.62" size="1.778" layer="95"/>
<pinref part="JP3" gate="A" pin="6"/>
</segment>
</net>
<net name="DIN" class="4">
<segment>
<pinref part="U3" gate="G$1" pin="DIN"/>
<wire x1="165.1" y1="-144.78" x2="147.32" y2="-144.78" width="0.1524" layer="91"/>
<label x="147.32" y="-144.78" size="1.778" layer="95"/>
</segment>
<segment>
<wire x1="-40.64" y1="-2.54" x2="-25.4" y2="-2.54" width="0.1524" layer="91"/>
<label x="-40.64" y="-2.54" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO7"/>
</segment>
<segment>
<wire x1="-68.58" y1="5.08" x2="-81.28" y2="5.08" width="0.1524" layer="91"/>
<label x="-81.28" y="5.08" size="1.778" layer="95"/>
<pinref part="JP3" gate="A" pin="1"/>
</segment>
</net>
<net name="BCLK" class="4">
<segment>
<wire x1="-68.58" y1="-10.16" x2="-81.28" y2="-10.16" width="0.1524" layer="91"/>
<label x="-81.28" y="-10.16" size="1.778" layer="95"/>
<pinref part="JP3" gate="A" pin="7"/>
</segment>
</net>
<net name="V0-" class="4">
<segment>
<pinref part="U3" gate="G$1" pin="OUTN"/>
<wire x1="200.66" y1="-142.24" x2="223.52" y2="-142.24" width="0.1524" layer="91"/>
<wire x1="223.52" y1="-142.24" x2="233.68" y2="-142.24" width="0.1524" layer="91"/>
<wire x1="223.52" y1="-142.24" x2="223.52" y2="-152.4" width="0.1524" layer="91"/>
<pinref part="C2" gate="G$1" pin="2"/>
<junction x="223.52" y="-142.24"/>
<label x="228.6" y="-142.24" size="1.778" layer="95"/>
</segment>
<segment>
<wire x1="228.6" y1="-73.66" x2="218.44" y2="-73.66" width="0.1524" layer="91"/>
<label x="218.44" y="-73.66" size="1.778" layer="95"/>
<pinref part="J1" gate="A" pin="2"/>
</segment>
</net>
<net name="V0+" class="4">
<segment>
<pinref part="U3" gate="G$1" pin="OUTP"/>
<wire x1="200.66" y1="-144.78" x2="213.36" y2="-144.78" width="0.1524" layer="91"/>
<wire x1="213.36" y1="-144.78" x2="233.68" y2="-144.78" width="0.1524" layer="91"/>
<wire x1="213.36" y1="-144.78" x2="213.36" y2="-152.4" width="0.1524" layer="91"/>
<pinref part="C3" gate="G$1" pin="2"/>
<junction x="213.36" y="-144.78"/>
<label x="228.6" y="-144.78" size="1.778" layer="95"/>
</segment>
<segment>
<wire x1="228.6" y1="-71.12" x2="218.44" y2="-71.12" width="0.1524" layer="91"/>
<label x="218.44" y="-71.12" size="1.778" layer="95"/>
<pinref part="J1" gate="A" pin="1"/>
</segment>
</net>
<net name="MIC_OUT" class="4">
<segment>
<wire x1="-25.4" y1="12.7" x2="-40.64" y2="12.7" width="0.1524" layer="91"/>
<label x="-40.64" y="12.7" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO1"/>
</segment>
<segment>
<pinref part="R9" gate="G$1" pin="1"/>
<wire x1="-25.4" y1="-172.72" x2="-25.4" y2="-185.42" width="0.1524" layer="91"/>
<label x="-25.4" y="-185.42" size="1.778" layer="95" rot="R90"/>
</segment>
<segment>
<wire x1="-93.98" y1="-5.08" x2="-106.68" y2="-5.08" width="0.1524" layer="91"/>
<label x="-106.68" y="-5.08" size="1.778" layer="95"/>
<pinref part="JP2" gate="A" pin="5"/>
</segment>
</net>
<net name="BLCK" class="4">
<segment>
<wire x1="-10.16" y1="-144.78" x2="-25.4" y2="-144.78" width="0.1524" layer="91"/>
<label x="-25.4" y="-144.78" size="1.778" layer="95"/>
<pinref part="MK1" gate="G$1" pin="SCK"/>
</segment>
<segment>
<pinref part="U3" gate="G$1" pin="BCLK"/>
<wire x1="165.1" y1="-142.24" x2="147.32" y2="-142.24" width="0.1524" layer="91"/>
<label x="147.32" y="-142.24" size="1.778" layer="95"/>
</segment>
<segment>
<wire x1="-25.4" y1="-17.78" x2="-40.64" y2="-17.78" width="0.1524" layer="91"/>
<label x="-40.64" y="-17.78" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO13"/>
</segment>
</net>
<net name="LR" class="4">
<segment>
<wire x1="-53.34" y1="-137.16" x2="-53.34" y2="-147.32" width="0.1524" layer="91"/>
<pinref part="R8" gate="G$1" pin="2"/>
<wire x1="-10.16" y1="-137.16" x2="-53.34" y2="-137.16" width="0.1524" layer="91"/>
<label x="-27.94" y="-137.16" size="1.778" layer="95"/>
<pinref part="MK1" gate="G$1" pin="LR"/>
</segment>
</net>
<net name="N$8" class="4">
<segment>
<wire x1="-10.16" y1="-147.32" x2="-25.4" y2="-147.32" width="0.1524" layer="91"/>
<wire x1="-25.4" y1="-147.32" x2="-25.4" y2="-157.48" width="0.1524" layer="91"/>
<pinref part="R9" gate="G$1" pin="2"/>
<pinref part="MK1" gate="G$1" pin="SD"/>
<wire x1="-25.4" y1="-157.48" x2="-25.4" y2="-162.56" width="0.1524" layer="91"/>
<junction x="-25.4" y="-157.48"/>
<wire x1="-25.4" y1="-157.48" x2="-12.7" y2="-157.48" width="0.1524" layer="91"/>
<wire x1="-12.7" y1="-157.48" x2="-12.7" y2="-162.56" width="0.1524" layer="91"/>
<pinref part="R11" gate="G$1" pin="2"/>
</segment>
</net>
<net name="GPIO14" class="4">
<segment>
<wire x1="-25.4" y1="-20.32" x2="-40.64" y2="-20.32" width="0.1524" layer="91"/>
<label x="-40.64" y="-20.32" size="1.778" layer="95"/>
<pinref part="U1" gate="G$1" pin="IO14"/>
</segment>
<segment>
<wire x1="-68.58" y1="-12.7" x2="-81.28" y2="-12.7" width="0.1524" layer="91"/>
<label x="-81.28" y="-12.7" size="1.778" layer="95"/>
<pinref part="JP3" gate="A" pin="8"/>
</segment>
</net>
<net name="N$1" class="4">
<segment>
<wire x1="5.08" y1="134.62" x2="-15.24" y2="134.62" width="0.1524" layer="91"/>
<wire x1="-15.24" y1="134.62" x2="-15.24" y2="121.92" width="0.1524" layer="91"/>
<pinref part="R4" gate="G$1" pin="2"/>
<pinref part="J3" gate="G$1" pin="CC1"/>
</segment>
</net>
<net name="N$2" class="4">
<segment>
<wire x1="5.08" y1="142.24" x2="-22.86" y2="142.24" width="0.1524" layer="91"/>
<wire x1="-22.86" y1="142.24" x2="-30.48" y2="142.24" width="0.1524" layer="91"/>
<wire x1="-22.86" y1="142.24" x2="-22.86" y2="127" width="0.1524" layer="91"/>
<junction x="-22.86" y="142.24"/>
<pinref part="J3" gate="G$1" pin="VBUS_A"/>
<pinref part="D1" gate="G$1" pin="A"/>
<pinref part="D13" gate="G$1" pin="A"/>
</segment>
</net>
<net name="N$7" class="4">
<segment>
<wire x1="86.36" y1="109.22" x2="86.36" y2="96.52" width="0.1524" layer="91"/>
<pinref part="SUPPLY26" gate="G$1" pin="GND"/>
<pinref part="D5" gate="G$1" pin="C"/>
</segment>
</net>
<net name="N$3" class="4">
<segment>
<wire x1="40.64" y1="127" x2="66.04" y2="127" width="0.1524" layer="91"/>
<wire x1="66.04" y1="127" x2="66.04" y2="119.38" width="0.1524" layer="91"/>
<pinref part="R5" gate="G$1" pin="2"/>
<pinref part="J3" gate="G$1" pin="CC2"/>
</segment>
</net>
</nets>
</sheet>
</sheets>
</schematic>
</drawing>
<compatibility>
<note version="6.3" minversion="6.2.2" severity="warning">
Since Version 6.2.2 text objects can contain more than one line,
which will not be processed correctly with this version.
</note>
<note version="8.2" severity="warning">
Since Version 8.2, EAGLE supports online libraries. The ids
of those online libraries will not be understood (or retained)
with this version.
</note>
<note version="8.3" severity="warning">
Since Version 8.3, EAGLE supports URNs for individual library
assets (packages, symbols, and devices). The URNs of those assets
will not be understood (or retained) with this version.
</note>
<note version="8.3" severity="warning">
Since Version 8.3, EAGLE supports the association of 3D packages
with devices in libraries, schematics, and board files. Those 3D
packages will not be understood (or retained) with this version.
</note>
<note version="8.4" severity="warning">
Since Version 8.4, EAGLE supports properties for SPICE simulation. 
Probes in schematics and SPICE mapping objects found in parts and library devices
will not be understood with this version. Update EAGLE to the latest version
for full support of SPICE simulation. 
</note>
</compatibility>
</eagle>
