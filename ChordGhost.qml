import MuseScore 3.0
import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2

MuseScore {
    menuPath: "Plugins.Chord Ghost"
    description: "Chord analysis, voicings, cadences and mood"
    version: "5.4.2"
    pluginType: "dialog"
    id: plugin
    width: 1400
    height: 800

    // ── COLORS ──
    property string c00: "#080808"
    property string c05: "#0F0F0F"
    property string c10: "#161616"
    property string c15: "#1E1E1E"
    property string c20: "#262626"
    property string c25: "#2E2E2E"
    property string c30: "#383838"
    property string c40: "#505050"
    property string c50: "#707070"
    property string c60: "#909090"
    property string c70: "#AAAAAA"
    property string c80: "#C8C8C8"
    property string c90: "#E0E0E0"
    property string cW:  "#FFFFFF"
    property string cSh: "#FF8A65"
    property string cFl: "#64B5F6"
    property string cNt: "#D0D0D0"

    // ── STATE ──
    property string selRoot: "C"
    property int selAcc: 0
    property string selQual: "maj"
    property int selVoice: 0
    property var activeNotes: []
    property string chordLbl: ""
    property string roman: ""
    property string curKey: "C"
    property int curKS: 0
    property bool minorMode: false

    property var seqChords: []
    property var detectedCadences: []
    property string detectedMood: ""
    property var nextSuggestions: []

    property bool pSeqOpen: true
    property bool pNextOpen: true
    property bool pCadOpen: true
    property bool pMoodOpen: true
    property bool pRefOpen: false

    // ── MUSIC DATA ──
    property var noteToSemi: { return {"C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11}; }
    property var rootList: { return ["C","D","E","F","G","A","B"]; }
    property var majorScaleIv: { return [0,2,4,5,7,9,11]; }
    property var romanLabels: { return ["I","II","III","IV","V","VI","VII"]; }
    property var diatonicQuals: { return ["maj","m","m","maj","maj","m","dim"]; }
    property var diatonicQualsMin: { return ["m","dim","maj","m","m","maj","maj"]; }
    property var minorScaleIv: { return [0,2,3,5,7,8,10]; }
    property var romanLabelsMin: { return ["i","ii","III","iv","v","VI","VII"]; }

    function getRelativeMinor(maj) {
        var m = {"C":"Am","G":"Em","D":"Bm","A":"F#m","E":"C#m","B":"G#m","F#":"D#m","C#":"A#m","F":"Dm","Bb":"Gm","Eb":"Cm","Ab":"Fm","Db":"Bbm","Gb":"Ebm","Cb":"Abm"};
        return m[maj] || "Am";
    }

    function setKeySig(ks) {
        curKS = ks;
        curKey = getKsMap(ks);
        buildChord();
    }

    function getFiguredBass(numNotes, inv) {
        if (numNotes <= 3) {
            if (inv === 0) return "";
            if (inv === 1) return "6";
            if (inv === 2) return "6/4";
        } else {
            if (inv === 0) return "7";
            if (inv === 1) return "6/5";
            if (inv === 2) return "4/3";
            if (inv === 3) return "2";
        }
        return "";
    }

    function buildInvNotes(invIdx, minM, maxM) {
        var ivs = getQualityData(selQual);
        var rs = rootSemi();
        var semis = [];
        var ii = 0;
        for (ii = 0; ii < ivs.length; ii++) {
            semis.push((rs + ivs[ii]) % 12);
        }
        var rr = 0;
        for (rr = 0; rr < invIdx && rr < semis.length - 1; rr++) {
            var tmp = semis.shift();
            semis.push(tmp);
        }
        var bassN = semis[0];
        var result = [];
        var bassMid = -1;
        var bo = 0;
        for (bo = 2; bo <= 6; bo++) {
            var bm = bassN + (bo + 1) * 12;
            if (bm >= minM && bm <= maxM) { bassMid = bm; break; }
        }
        if (bassMid < 0) return result;
        var bassNm = nn(bassN);
        var bassOct = Math.floor(bassMid / 12) - 1;
        result.push({midi: bassMid, name: bassNm, fullName: bassNm + bassOct, accidental: accType(bassNm), isRoot: (bassN === rs), isBass: true});
        var si = 0;
        for (si = 1; si < semis.length; si++) {
            var sm2 = semis[si];
            var nm2 = nn(sm2);
            var prevM = result[result.length - 1].midi;
            var oc2 = 0;
            for (oc2 = 2; oc2 <= 6; oc2++) {
                var mid2 = sm2 + (oc2 + 1) * 12;
                if (mid2 > prevM && mid2 >= minM && mid2 <= maxM) {
                    var oct2 = Math.floor(mid2 / 12) - 1;
                    result.push({midi: mid2, name: nm2, fullName: nm2 + oct2, accidental: accType(nm2), isRoot: (sm2 === rs), isBass: false});
                    break;
                }
            }
        }
        return result;
    }

    function getNoteNameSharp(s) {
        var arr = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];
        return arr[s % 12];
    }
    function getNoteNameFlat(s) {
        var arr = ["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"];
        return arr[s % 12];
    }
    function nn(s) {
        if (selAcc < 0 || curKS < 0) return getNoteNameFlat(s);
        return getNoteNameSharp(s);
    }
    function accType(name) {
        if (name.indexOf("#") >= 0) return "sharp";
        if (name.indexOf("b") >= 0 && name !== "B") return "flat";
        return "natural";
    }

    function getQualityData(qKey) {
        var map = {
            "maj": [0,4,7], "m": [0,3,7], "dim": [0,3,6], "aug": [0,4,8],
            "sus2": [0,2,7], "sus4": [0,5,7],
            "7": [0,4,7,10], "maj7": [0,4,7,11], "m7": [0,3,7,10],
            "dim7": [0,3,6,9], "hdim7": [0,3,6,10], "aug7": [0,4,8,10], "mM7": [0,3,7,11],
            "6": [0,4,7,9], "m6": [0,3,7,9],
            "9": [0,4,7,10,14], "maj9": [0,4,7,11,14], "m9": [0,3,7,10,14], "add9": [0,4,7,14],
            "7b5": [0,4,6,10], "7s5": [0,4,8,10], "7b9": [0,4,7,10,13], "7s9": [0,4,7,10,15],
            "11": [0,4,7,10,14,17], "13": [0,4,7,10,14,17,21], "5": [0,7]
        };
        return map[qKey] || [0,4,7];
    }

    function getQualityLabel(qKey) {
        var map = {
            "maj":"Major","m":"Minor","dim":"Dim","aug":"Aug",
            "sus2":"Sus2","sus4":"Sus4",
            "7":"Dom7","maj7":"Maj7","m7":"Min7","dim7":"Dim7",
            "hdim7":"Half-dim","aug7":"Aug7","mM7":"mMaj7",
            "6":"Maj6","m6":"Min6",
            "9":"Dom9","maj9":"Maj9","m9":"Min9","add9":"Add9",
            "7b5":"7b5","7s5":"7#5","7b9":"7b9","7s9":"7#9",
            "11":"Dom11","13":"Dom13","5":"Power5"
        };
        return map[qKey] || qKey;
    }

    property var qualCats: {
        return [
            {t:"Triads", q:["maj","m","dim","aug","sus2","sus4"]},
            {t:"7ths",   q:["7","maj7","m7","dim7","hdim7","aug7","mM7"]},
            {t:"Ext",    q:["6","m6","9","maj9","m9","add9"]},
            {t:"Alt",    q:["7b5","7s5","7b9","7s9","11","13","5"]}
        ];
    }

    property var voicingLabels: { return ["Root","1st Inv","2nd Inv","3rd Inv","Open","Close"]; }

    function getKsMap(ks) {
        var map = {"-7":"Cb","-6":"Gb","-5":"Db","-4":"Ab","-3":"Eb","-2":"Bb","-1":"F","0":"C","1":"G","2":"D","3":"A","4":"E","5":"B","6":"F#","7":"C#"};
        return map[ks.toString()] || "C";
    }

    // Transitions: degree -> [{d:degree, w:weight}]
    function getTransitions(deg) {
        var map = {
            "I":   [{d:"IV",w:25},{d:"V",w:25},{d:"vi",w:20},{d:"ii",w:15},{d:"iii",w:10}],
            "ii":  [{d:"V",w:40},{d:"IV",w:20},{d:"I",w:15},{d:"iii",w:15},{d:"vi",w:10}],
            "iii": [{d:"vi",w:30},{d:"IV",w:25},{d:"ii",w:20},{d:"I",w:15},{d:"V",w:10}],
            "IV":  [{d:"V",w:30},{d:"I",w:25},{d:"ii",w:15},{d:"vi",w:15},{d:"iii",w:15}],
            "V":   [{d:"I",w:40},{d:"vi",w:25},{d:"IV",w:15},{d:"iii",w:10},{d:"ii",w:10}],
            "vi":  [{d:"IV",w:25},{d:"ii",w:25},{d:"V",w:20},{d:"I",w:15},{d:"iii",w:15}],
            "vii": [{d:"I",w:45},{d:"iii",w:25},{d:"vi",w:15},{d:"V",w:10},{d:"IV",w:5}]
        };
        return map[deg] || map["I"];
    }

    // Mood fingerprints
    function getMoodFingerprints() {
        return [
            {name:"Luminoso",    icon:"*",  desc:"Abierto, esperanzador", wMaj:3, wMin:0, wDim:-2, chords:"I - IV - V"},
            {name:"Melancolico", icon:"~",  desc:"Triste pero hermoso",   wMaj:1, wMin:3, wDim:0,  chords:"vi - IV - I - V"},
            {name:"Tension",     icon:"!",  desc:"Suspenso, inestable",   wMaj:0, wMin:1, wDim:3,  chords:"V7 - vii - bII"},
            {name:"Epico",       icon:"^",  desc:"Grandioso, cinematico", wMaj:2, wMin:1, wDim:-1, chords:"I - bVI - bVII - IV"},
            {name:"Onirico",     icon:"+",  desc:"Flotante, etereo",      wMaj:2, wMin:2, wDim:0,  chords:"Imaj7 - IVmaj7 - ii7"},
            {name:"Oscuro",      icon:"-",  desc:"Sombrio, misterio",     wMaj:-1,wMin:3, wDim:2,  chords:"i - bVI - bIII - bVII"},
            {name:"Nostalgico",  icon:"o",  desc:"Agridulce, recuerdos",  wMaj:2, wMin:2, wDim:0,  chords:"I - iii - vi - IV"},
            {name:"Triunfante",  icon:"#",  desc:"Victoria, resolucion",  wMaj:3, wMin:-1,wDim:0,  chords:"I - IV - V - V/V"}
        ];
    }

    // Reference cadences
    function getRefCadences() {
        return [
            {n:"Autentica Perfecta",  d:"V -> I",             x:"Cierre definitivo"},
            {n:"Plagal",              d:"IV -> I",             x:"Cadencia Amen"},
            {n:"Semicadencia",        d:"? -> V",              x:"Pausa en dominante"},
            {n:"Deceptiva",           d:"V -> vi",             x:"Resolucion inesperada"},
            {n:"Completa",            d:"ii/IV -> V -> I",     x:"S -> D -> T"},
            {n:"Frigia",              d:"bII -> I",            x:"Napolitano a tonica"},
            {n:"Romantica",           d:"I -> vi -> IV -> V",  x:"Pop universal"},
            {n:"Andaluza",            d:"i -> bVII -> bVI -> V",x:"Flamenco descendente"},
            {n:"Royal Road",          d:"IV -> V -> iii -> vi", x:"J-Pop emotiva"},
            {n:"Axis",                d:"I -> V -> vi -> IV",   x:"Pop moderno hit"}
        ];
    }

    // ── STAFF ──
    property int staffSp: 15
    property int trebleY: 50
    property int bassY: 230

    function midiToY(midi) {
        var dPos = [0,0,1,1,2,3,3,4,4,5,5,6];
        var semi = midi % 12;
        var oct = Math.floor(midi / 12) - 1;
        var steps = oct * 7 + dPos[semi];
        var half = staffSp / 2.0;
        if (steps >= 28) {
            return trebleY + (38 - steps) * half;
        } else {
            return bassY + (26 - steps) * half;
        }
    }

    // ── CHORD LOGIC ──
    function rootSemi() {
        var base = noteToSemi[selRoot] || 0;
        return (base + selAcc + 12) % 12;
    }

    function keyRootSemi() {
        var kn = curKey || "C";
        var kb = kn.charAt(0);
        var ka = 0;
        if (kn.length > 1) {
            if (kn.charAt(1) === '#') ka = 1;
            else ka = -1;
        }
        var base = noteToSemi[kb] || 0;
        return (base + ka + 12) % 12;
    }

    function semiToRoman(semi, qual) {
        var kr = keyRootSemi();
        var iv = (semi - kr + 12) % 12;
        var deg = -1;
        var msi = majorScaleIv;
        for (var i = 0; i < msi.length; i++) {
            if (msi[i] === iv) { deg = i; break; }
        }
        if (deg >= 0) {
            var rn = romanLabels[deg];
            var isMin = (qual === "m" || qual === "m7" || qual === "dim" || qual === "dim7" ||
                         qual === "hdim7" || qual === "m9" || qual === "m6" || qual === "mM7");
            if (isMin) rn = rn.toLowerCase();
            if (qual === "dim" || qual === "dim7") rn += "o";
            else if (qual === "aug" || qual === "aug7") rn += "+";
            else if (qual === "hdim7") rn += "o/";
            if (qual.indexOf("7") >= 0 || qual === "dim7" || qual === "hdim7" || qual === "mM7") rn += "7";
            if (qual.indexOf("9") >= 0) rn += "9";
            if (qual === "sus2") rn += "sus2";
            if (qual === "sus4") rn += "sus4";
            if (qual === "6" || qual === "m6") rn += "6";
            return rn;
        }
        var chrMap = {1:"bII", 3:"bIII", 6:"#IV", 8:"bVI", 10:"bVII"};
        return chrMap[iv] || "?";
    }

    function getSimpleRoman(fullRoman) {
        return fullRoman.replace(/[o\/0-9\+]/g, "").replace("sus","").replace("b","");
    }

    function buildChord() {
        var ivs = getQualityData(selQual);
        var rs = rootSemi();

        var rl = selRoot;
        if (selAcc === 1) rl += "#";
        else if (selAcc === -1) rl += "b";
        chordLbl = rl + (selQual !== "maj" ? selQual : "");

        var semis = [];
        for (var i = 0; i < ivs.length; i++) {
            semis.push((rs + ivs[i]) % 12);
        }

        // Apply voicing reorder
        if (selVoice === 1 && semis.length >= 3) {
            var t = semis.shift(); semis.push(t);
        } else if (selVoice === 2 && semis.length >= 3) {
            var a1 = semis.shift(); var a2 = semis.shift(); semis.push(a1); semis.push(a2);
        } else if (selVoice === 3 && semis.length >= 4) {
            var b1 = semis.shift(); var b2 = semis.shift(); var b3 = semis.shift();
            semis.push(b1); semis.push(b2); semis.push(b3);
        }

        var notes = [];
        for (var si = 0; si < semis.length; si++) {
            var sm = semis[si];
            var nm = nn(sm);
            var ac = accType(nm);
            for (var oc = 2; oc <= 5; oc++) {
                var mid = sm + (oc + 1) * 12;
                if (mid < 40 || mid > 83) continue;
                if (selVoice === 5 && (mid < 48 || mid > 72)) continue;
                if (selVoice === 4 && (oc + si) % 2 !== 0) continue;
                notes.push({midi: mid, name: nm, fullName: nm + oc, accidental: ac, isRoot: (sm === rs)});
            }
        }
        notes.sort(function(a, b) { return a.midi - b.midi; });
        activeNotes = notes;
        roman = semiToRoman(rs, selQual);
        staffCanvas.requestPaint();
    }

    // ── CONTEXTUAL ENGINE ──
    function readSequence() {
        if (!curScore) return;
        var cursor = curScore.newCursor();

        cursor.rewind(1);
        if (cursor.keySignature !== undefined) {
            curKS = cursor.keySignature;
            curKey = getKsMap(curKS);
        }

        // Auto-detect minor mode: check if most bass notes are on minor root
        // We will refine after collecting pitches

        cursor.rewind(2);
        var endTick = cursor.tick;
        if (endTick === 0) endTick = curScore.lastSegment.tick + 1;

        var measurePitches = {};
        var nStaves = curScore.nstaves;
        for (var staff = 0; staff < nStaves; staff++) {
            for (var voice = 0; voice < 4; voice++) {
                cursor.rewind(1);
                cursor.voice = voice;
                cursor.staffIdx = staff;
                while (cursor.segment && cursor.tick < endTick) {
                    if (cursor.element && cursor.element.type === Element.CHORD) {
                        var mNum = cursor.measure.no;
                        if (!measurePitches[mNum]) measurePitches[mNum] = [];
                        var cNotes = cursor.element.notes;
                        for (var ni = 0; ni < cNotes.length; ni++) {
                            measurePitches[mNum].push(cNotes[ni].pitch % 12);
                        }
                    }
                    cursor.next();
                }
            }
        }

        var mNums = Object.keys(measurePitches).sort(function(a, b) { return parseInt(a) - parseInt(b); });
        var seq = [];
        var allQKeys = Object.keys({"maj":1,"m":1,"dim":1,"aug":1,"sus2":1,"sus4":1,"7":1,"maj7":1,"m7":1,"dim7":1,"hdim7":1,"aug7":1,"mM7":1,"6":1,"m6":1,"9":1,"maj9":1,"m9":1,"add9":1,"7b5":1,"7s5":1,"7b9":1,"7s9":1,"11":1,"13":1,"5":1});

        for (var mi = 0; mi < mNums.length; mi++) {
            var pcs = {};
            var raw = measurePitches[mNums[mi]];
            for (var pi = 0; pi < raw.length; pi++) pcs[raw[pi]] = true;
            var pa = Object.keys(pcs).map(function(k) { return parseInt(k); });
            if (pa.length === 0) continue;
            pa.sort(function(a, b) { return a - b; });

            var best = null;
            var bestSc = -1;
            for (var r = 0; r < pa.length; r++) {
                for (var qi = 0; qi < allQKeys.length; qi++) {
                    var qKey = allQKeys[qi];
                    var qIvs = getQualityData(qKey);
                    var exp = {};
                    for (var ei = 0; ei < qIvs.length; ei++) exp[(pa[r] + qIvs[ei]) % 12] = true;
                    var mt = 0;
                    for (var pi2 = 0; pi2 < pa.length; pi2++) if (exp[pa[pi2]]) mt++;
                    var ec = Object.keys(exp).length;
                    var sc = mt * 10 - Math.abs(ec - pa.length);
                    if (mt === pa.length && mt === ec) sc += 100;
                    if (sc > bestSc) { bestSc = sc; best = {root: pa[r], quality: qKey}; }
                }
            }
            if (best) {
                var cnm = nn(best.root);
                var croman = semiToRoman(best.root, best.quality);
                seq.push({root: best.root, quality: best.quality, name: cnm + (best.quality !== "maj" ? best.quality : ""), roman: croman, measure: parseInt(mNums[mi])});
            }
        }

        seqChords = seq;

        // Auto-detect minor mode: if first chord or most chords are minor root
        if (seq.length > 0) {
            var majRoot = keyRootSemi();
            var minRoot = (majRoot + 9) % 12;
            var majCount = 0;
            var minCount = 0;
            var idx = 0;
            for (idx = 0; idx < seq.length; idx++) {
                if (seq[idx].root === majRoot) majCount++;
                if (seq[idx].root === minRoot) minCount++;
            }
            if (minCount > majCount) {
                minorMode = true;
            } else {
                minorMode = false;
            }
        }

        detectCadencesCtx();
        detectMoodCtx();
        suggestNextCtx();
    }

    function detectCadencesCtx() {
        var found = [];
        var seq = seqChords;
        if (seq.length < 2) { detectedCadences = found; return; }

        for (var i = 0; i < seq.length - 1; i++) {
            var r1 = getSimpleRoman(seq[i].roman);
            var r2 = getSimpleRoman(seq[i + 1].roman);

            if ((r1 === "V" || r1 === "V7") && r2 === "I")
                found.push({name: "Autentica", degrees: seq[i].roman + " -> " + seq[i+1].roman, pos: "c." + (seq[i].measure + 1)});
            else if (r1 === "IV" && r2 === "I")
                found.push({name: "Plagal", degrees: seq[i].roman + " -> " + seq[i+1].roman, pos: "c." + (seq[i].measure + 1)});
            else if ((r1 === "V" || r1 === "V7") && r2 === "vi")
                found.push({name: "Deceptiva", degrees: seq[i].roman + " -> " + seq[i+1].roman, pos: "c." + (seq[i].measure + 1)});
            else if (r2 === "V")
                found.push({name: "Semicadencia", degrees: seq[i].roman + " -> " + seq[i+1].roman, pos: "c." + (seq[i].measure + 1)});

            if (i + 2 < seq.length) {
                var r3 = getSimpleRoman(seq[i+2].roman);
                if ((r1 === "IV" || r1 === "ii") && r2 === "V" && r3 === "I")
                    found.push({name: "Completa", degrees: seq[i].roman + " -> " + seq[i+1].roman + " -> " + seq[i+2].roman, pos: "c." + (seq[i].measure + 1) + "-" + (seq[i+2].measure + 1)});
            }
        }
        detectedCadences = found;
    }

    function detectMoodCtx() {
        if (seqChords.length === 0) { detectedMood = ""; return; }
        var majC = 0; var minC = 0; var dimC = 0;
        for (var i = 0; i < seqChords.length; i++) {
            var q = seqChords[i].quality;
            if (q === "maj" || q === "7" || q === "maj7" || q === "6") majC++;
            else if (q === "m" || q === "m7" || q === "m9" || q === "m6") minC++;
            else if (q === "dim" || q === "dim7" || q === "hdim7") dimC++;
        }
        var moods = getMoodFingerprints();
        var bestMood = "";
        var bestScore = -999;
        for (var mi = 0; mi < moods.length; mi++) {
            var sc = moods[mi].wMaj * majC + moods[mi].wMin * minC + moods[mi].wDim * dimC;
            if (sc > bestScore) { bestScore = sc; bestMood = moods[mi].name; }
        }
        detectedMood = bestMood;
    }

    function suggestNextCtx() {
        if (seqChords.length === 0) { nextSuggestions = []; return; }
        var last = seqChords[seqChords.length - 1];
        var lastR = getSimpleRoman(last.roman);
        if (lastR === lastR.toLowerCase() && lastR !== "vi" && lastR !== "ii" && lastR !== "iii" && lastR !== "vii") {
            lastR = lastR.charAt(0).toUpperCase() + lastR.slice(1);
        }
        var trans = getTransitions(lastR);
        var suggestions = [];
        var kr = keyRootSemi();
        var msi = majorScaleIv;
        var rl = romanLabels;

        for (var ti = 0; ti < trans.length; ti++) {
            var target = trans[ti];
            var deg = target.d;
            var degUpper = deg.toUpperCase();
            var degIdx = -1;
            for (var di = 0; di < rl.length; di++) {
                if (rl[di] === degUpper.replace("B","").replace("#","")) { degIdx = di; break; }
            }
            if (degIdx < 0) continue;

            var degQual = (deg !== deg.toUpperCase()) ? "m" : "maj";
            var semi = (kr + msi[degIdx]) % 12;
            var chName = nn(semi) + (degQual !== "maj" ? degQual : "");
            var reason = "";
            if (target.w >= 40) reason = "Strong resolution";
            else if (target.w >= 25) reason = "Natural motion";
            else if (target.w >= 15) reason = "Interesting color";
            else reason = "Surprise";

            suggestions.push({chord: chName, roman: deg, weight: target.w, reason: reason, semi: semi, qual: degQual});
        }
        suggestions.sort(function(a, b) { return b.weight - a.weight; });
        nextSuggestions = suggestions.slice(0, 5);
    }

    function drawNoteAt(ctx, noteObj, cx, nW, nH, showLabel) {
        var noteY = midiToY(noteObj.midi);
        var ncH = cNt;
        if (noteObj.accidental === "sharp") ncH = cSh;
        else if (noteObj.accidental === "flat") ncH = cFl;
        if (noteObj.isBass) ncH = "#4FC3F7";
        var rgb = hexToRgb(ncH);
        var tB2 = trebleY + 4 * staffSp;
        var bB2 = bassY + 4 * staffSp;
        var mcY2 = midiToY(60);

        // Ledger lines
        ctx.strokeStyle = c60;
        ctx.lineWidth = 0.7;
        if (noteY < trebleY) {
            var ledg = trebleY - staffSp;
            while (ledg >= noteY - 1) {
                ctx.beginPath(); ctx.moveTo(cx - 14, ledg); ctx.lineTo(cx + 14, ledg); ctx.stroke();
                ledg = ledg - staffSp;
            }
        }
        if (noteY > tB2 && noteY < bassY && Math.abs(noteY - mcY2) < 2) {
            ctx.beginPath(); ctx.moveTo(cx - 14, mcY2); ctx.lineTo(cx + 14, mcY2); ctx.stroke();
        }
        if (noteY > bB2) {
            var ledg2 = bB2 + staffSp;
            while (ledg2 <= noteY + 1) {
                ctx.beginPath(); ctx.moveTo(cx - 14, ledg2); ctx.lineTo(cx + 14, ledg2); ctx.stroke();
                ledg2 = ledg2 + staffSp;
            }
        }

        // Note head
        var alph = noteObj.isRoot ? 0.65 : (noteObj.isBass ? 0.75 : 0.35);
        ctx.fillStyle = Qt.rgba(rgb.r, rgb.g, rgb.b, alph);
        drawEllipse(ctx, cx, noteY, nW, nH / 2);
        ctx.fill();
        ctx.strokeStyle = Qt.rgba(rgb.r, rgb.g, rgb.b, alph + 0.15);
        ctx.lineWidth = (noteObj.isRoot || noteObj.isBass) ? 1.3 : 0.8;
        drawEllipse(ctx, cx, noteY, nW, nH / 2);
        ctx.stroke();

        // Labels
        if (showLabel) {
            ctx.fillStyle = Qt.rgba(rgb.r, rgb.g, rgb.b, 0.6);
            ctx.font = "10px sans-serif";
            ctx.textAlign = "left";
            ctx.fillText(noteObj.fullName, cx + nW + 3, noteY + 3);
            if (noteObj.accidental !== "natural") {
                ctx.font = "12px sans-serif";
                ctx.textAlign = "right";
                ctx.fillText(noteObj.accidental === "sharp" ? "#" : "b", cx - nW - 2, noteY + 3);
            }
            ctx.textAlign = "start";
        }
    }

    // ── DRAW HELPERS ──
    function drawEllipse(ctx, cx, cy, rx, ry) {
        ctx.beginPath();
        ctx.moveTo(cx + rx, cy);
        ctx.bezierCurveTo(cx + rx, cy - ry * 0.55, cx + rx * 0.55, cy - ry, cx, cy - ry);
        ctx.bezierCurveTo(cx - rx * 0.55, cy - ry, cx - rx, cy - ry * 0.55, cx - rx, cy);
        ctx.bezierCurveTo(cx - rx, cy + ry * 0.55, cx - rx * 0.55, cy + ry, cx, cy + ry);
        ctx.bezierCurveTo(cx + rx * 0.55, cy + ry, cx + rx, cy + ry * 0.55, cx + rx, cy);
        ctx.closePath();
    }

    function hexToRgb(hex) {
        var r = parseInt(hex.substr(1, 2), 16) / 255;
        var g = parseInt(hex.substr(3, 2), 16) / 255;
        var b = parseInt(hex.substr(5, 2), 16) / 255;
        return {r: r, g: g, b: b};
    }

    // ══════════════════════════════════════════
    // UI
    // ══════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        color: c00

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 0

            // ── HEADER ──
            RowLayout {
                Layout.fillWidth: true
                height: 44
                spacing: 10

                Text { text: "CHORD GHOST"; color: c90; font.pixelSize: 18; font.bold: true; font.letterSpacing: 4 }
                Rectangle { width: 1; height: 22; color: c30 }
                Text {
                    text: {
                        if (minorMode) {
                            return getRelativeMinor(curKey).replace("m","") + " MINOR";
                        }
                        return curKey + " MAJOR";
                    }
                    color: c50; font.pixelSize: 13; font.letterSpacing: 2
                }

                Row {
                    spacing: 4
                    Rectangle {
                        width: 60; height: 28; radius: 2
                        color: !minorMode ? cW : c20
                        Text { anchors.centerIn: parent; text: "MAJ"; color: !minorMode ? c00 : c60; font.pixelSize: 12; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { minorMode = false; buildChord(); } }
                    }
                    Rectangle {
                        width: 60; height: 28; radius: 2
                        color: minorMode ? cW : c20
                        Text { anchors.centerIn: parent; text: "MIN"; color: minorMode ? c00 : c60; font.pixelSize: 12; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { minorMode = true; buildChord(); } }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 130; height: 30; radius: 2; color: c15
                    border.color: c30; border.width: 1

                    Text { anchors.centerIn: parent; text: "ANALYZE"; color: c80; font.pixelSize: 12; font.letterSpacing: 1; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: parent.color = c25
                        onExited: parent.color = c15
                        onClicked: readSequence()
                    }
                }
            }

            // ── KEY SIGNATURE SELECTOR ──
            RowLayout {
                Layout.fillWidth: true
                height: 36
                spacing: 4

                Text { text: "KEY"; color: c40; font.pixelSize: 13; font.letterSpacing: 2; font.bold: true }

                Repeater {
                    model: [7,6,5,4,3,2,1]
                    Rectangle {
                        width: 32; height: 26; radius: 2
                        color: curKS === -modelData ? cW : c15
                        Text { anchors.centerIn: parent; text: modelData + "b"; color: curKS === -modelData ? c00 : c50; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { setKeySig(-modelData); } }
                    }
                }

                Rectangle {
                    width: 32; height: 26; radius: 2
                    color: curKS === 0 ? cW : c15
                    Text { anchors.centerIn: parent; text: "0"; color: curKS === 0 ? c00 : c50; font.pixelSize: 12; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { setKeySig(0); } }
                }

                Repeater {
                    model: [1,2,3,4,5,6,7]
                    Rectangle {
                        width: 32; height: 26; radius: 2
                        color: curKS === modelData ? cW : c15
                        Text { anchors.centerIn: parent; text: modelData + "#"; color: curKS === modelData ? c00 : c50; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { setKeySig(modelData); } }
                    }
                }

                Item { Layout.fillWidth: true }
                Text {
                    text: {
                        if (minorMode) return getRelativeMinor(curKey).replace("m","") + " min";
                        return curKey + " maj";
                    }
                    color: c60; font.pixelSize: 12
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: c25; Layout.topMargin: 4; Layout.bottomMargin: 6 }

            // ── BODY ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // ═══ LEFT: CHORD BUILDER ═══
                Rectangle {
                    Layout.preferredWidth: 230
                    Layout.fillHeight: true
                    color: c05
                    radius: 3

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 8
                        contentHeight: leftCol.height
                        clip: true
                        flickableDirection: Flickable.VerticalFlick

                        Column {
                            id: leftCol
                            width: parent.width
                            spacing: 6

                            Text { text: chordLbl || "-"; color: cW; font.pixelSize: 42; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }

                            Text {
                                visible: activeNotes.length > 0
                                text: {
                                    var s = {}; var a = [];
                                    for (var i = 0; i < activeNotes.length; i++) {
                                        if (!s[activeNotes[i].name]) { s[activeNotes[i].name] = true; a.push(activeNotes[i].name); }
                                    }
                                    return a.join("  ");
                                }
                                color: c50; font.pixelSize: 15; anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Rectangle { width: parent.width; height: 1; color: c25 }

                            Text { text: "ROOT"; color: c40; font.pixelSize: 11; font.letterSpacing: 2; font.bold: true }
                            Row {
                                spacing: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                Repeater {
                                    model: ["C","D","E","F","G","A","B"]
                                    Rectangle {
                                        width: 28; height: 28; radius: 2
                                        color: modelData === selRoot ? cW : c20
                                        Text { anchors.centerIn: parent; text: modelData; color: modelData === selRoot ? c00 : c60; font.pixelSize: 14; font.bold: modelData === selRoot }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { selRoot = modelData; buildChord(); } }
                                    }
                                }
                            }

                            Text { text: "ACCIDENTAL"; color: c40; font.pixelSize: 11; font.letterSpacing: 2; font.bold: true }
                            Row {
                                spacing: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                Rectangle {
                                    width: 46; height: 28; radius: 2; color: selAcc === -1 ? cW : c20
                                    Text { anchors.centerIn: parent; text: "b"; color: selAcc === -1 ? c00 : c60; font.pixelSize: 15 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { selAcc = -1; buildChord(); } }
                                }
                                Rectangle {
                                    width: 46; height: 28; radius: 2; color: selAcc === 0 ? cW : c20
                                    Text { anchors.centerIn: parent; text: "nat"; color: selAcc === 0 ? c00 : c60; font.pixelSize: 13 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { selAcc = 0; buildChord(); } }
                                }
                                Rectangle {
                                    width: 46; height: 28; radius: 2; color: selAcc === 1 ? cW : c20
                                    Text { anchors.centerIn: parent; text: "#"; color: selAcc === 1 ? c00 : c60; font.pixelSize: 15 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { selAcc = 1; buildChord(); } }
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: c25 }

                            Text { text: "QUALITY"; color: c40; font.pixelSize: 12; font.letterSpacing: 2; font.bold: true }
                            Repeater {
                                model: 4
                                Column {
                                    width: parent.width
                                    spacing: 1
                                    property var catData: qualCats[index]
                                    Text { text: catData.t; color: c40; font.pixelSize: 10; topPadding: index > 0 ? 2 : 0 }
                                    Flow {
                                        width: parent.width
                                        spacing: 2
                                        Repeater {
                                            model: catData.q
                                            Rectangle {
                                                width: Math.max(38, qLabel.width + 10); height: 24; radius: 2
                                                color: selQual === modelData ? cW : c20
                                                Text { id: qLabel; anchors.centerIn: parent; text: modelData; color: selQual === modelData ? c00 : c50; font.pixelSize: 12 }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { selQual = modelData; buildChord(); } }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle { width: parent.width; height: 1; color: c25 }
                            Row {
                                spacing: 14; anchors.horizontalCenter: parent.horizontalCenter
                                Row { spacing: 4; Rectangle { width: 10; height: 10; radius: 5; color: cNt; anchors.verticalCenter: parent.verticalCenter } Text { text: "nat"; color: c40; font.pixelSize: 11 } }
                                Row { spacing: 4; Rectangle { width: 10; height: 10; radius: 5; color: cSh; anchors.verticalCenter: parent.verticalCenter } Text { text: "#"; color: c40; font.pixelSize: 11 } }
                                Row { spacing: 4; Rectangle { width: 10; height: 10; radius: 5; color: cFl; anchors.verticalCenter: parent.verticalCenter } Text { text: "b"; color: c40; font.pixelSize: 11 } }
                            }
                        }
                    }
                }

                // ═══ CENTER: STAFF ═══
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Canvas {
                            id: staffCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            onPaint: {
                                var ctx = getContext("2d");
                                var w = width;
                                var h = height;
                                ctx.clearRect(0, 0, w, h);

                                var lx = 30;
                                var rx = w - 8;
                                var tB = trebleY + 4 * staffSp;
                                var bB = bassY + 4 * staffSp;
                                var mcY = midiToY(60);

                                // Treble staff
                                ctx.strokeStyle = c60;
                                ctx.lineWidth = 0.7;
                                for (var i = 0; i < 5; i++) {
                                    var y = trebleY + i * staffSp;
                                    ctx.beginPath(); ctx.moveTo(lx, y); ctx.lineTo(rx, y); ctx.stroke();
                                }
                                // Bass staff
                                for (var j = 0; j < 5; j++) {
                                    var yb = bassY + j * staffSp;
                                    ctx.beginPath(); ctx.moveTo(lx, yb); ctx.lineTo(rx, yb); ctx.stroke();
                                }
                                // Barlines
                                ctx.strokeStyle = c50;
                                ctx.lineWidth = 1;
                                ctx.beginPath(); ctx.moveTo(lx, trebleY); ctx.lineTo(lx, tB); ctx.stroke();
                                ctx.beginPath(); ctx.moveTo(lx, bassY); ctx.lineTo(lx, bB); ctx.stroke();

                                // Clefs
                                ctx.fillStyle = c70;
                                ctx.font = "28px serif";
                                ctx.textAlign = "start";
                                ctx.fillText("\uD834\uDD1E", lx + 2, trebleY + 2.8 * staffSp);
                                ctx.fillText("\uD834\uDD22", lx + 2, bassY + 1.5 * staffSp);

                                // Middle C
                                ctx.strokeStyle = c25;
                                ctx.lineWidth = 0.3;
                                ctx.setLineDash([2, 3]);
                                ctx.beginPath(); ctx.moveTo(lx + 20, mcY); ctx.lineTo(rx, mcY); ctx.stroke();
                                ctx.setLineDash([]);

                                if (activeNotes.length === 0) {
                                    ctx.fillStyle = c40;
                                    ctx.font = "16px sans-serif";
                                    ctx.textAlign = "center";
                                    ctx.fillText("Select a chord", (lx + rx) / 2, (trebleY + bassY) / 2);
                                    ctx.textAlign = "start";
                                    return;
                                }

                                var nW = 8;
                                var nH = staffSp - 2;
                                var nChordN = getQualityData(selQual).length;
                                var numInv = Math.min(nChordN, 4);
                                var numCols = 1 + numInv;
                                var areaStart = lx + 50;
                                var colWidth = (rx - areaStart) / numCols;

                                for (var col = 0; col < numCols; col++) {
                                    var colLeft = areaStart + col * colWidth;
                                    var colCenter = colLeft + colWidth / 2;

                                    // Column separator
                                    if (col > 0) {
                                        ctx.strokeStyle = c30;
                                        ctx.lineWidth = 0.4;
                                        ctx.beginPath();
                                        ctx.moveTo(colLeft, trebleY - 20);
                                        ctx.lineTo(colLeft, bB + 15);
                                        ctx.stroke();
                                    }

                                    // Column label
                                    ctx.fillStyle = c60;
                                    ctx.font = "bold 13px sans-serif";
                                    ctx.textAlign = "center";
                                    if (col === 0) {
                                        ctx.fillText("ALL", colCenter, trebleY - 14);
                                    } else {
                                        var invLbl = (col === 1) ? "Root" : (col === 2) ? "1st" : (col === 3) ? "2nd" : "3rd";
                                        ctx.fillText(invLbl, colCenter, trebleY - 22);
                                        var fb = getFiguredBass(nChordN, col - 1);
                                        if (fb.length > 0) {
                                            ctx.fillStyle = c50;
                                            ctx.font = "11px sans-serif";
                                            ctx.fillText(fb, colCenter, trebleY - 8);
                                        }
                                    }
                                    ctx.textAlign = "start";

                                    // Get notes for this column
                                    if (col === 0) {
                                        // Draw ALL notes
                                        for (var na = 0; na < activeNotes.length; na++) {
                                            drawNoteAt(ctx, activeNotes[na], colCenter, nW, nH, false);
                                        }
                                    } else {
                                        // Draw inversion notes
                                        var tNotes = buildInvNotes(col - 1, 60, 83);
                                        var bNotes = buildInvNotes(col - 1, 40, 59);
                                        var nb = 0;
                                        for (nb = 0; nb < bNotes.length; nb++) {
                                            drawNoteAt(ctx, bNotes[nb], colCenter, nW, nH, true);
                                        }
                                        var nt2 = 0;
                                        for (nt2 = 0; nt2 < tNotes.length; nt2++) {
                                            drawNoteAt(ctx, tNotes[nt2], colCenter, nW, nH, true);
                                        }
                                    }
                                }

                                // Voicing label
                                ctx.fillStyle = c40;
                                ctx.font = "12px sans-serif";
                                ctx.textAlign = "center";
                                ctx.fillText(voicingLabels[selVoice], (lx + rx) / 2, bB + 22);
                                ctx.textAlign = "start";
                            }
                        }

                        // ── DIATONIC BUTTONS ──
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6
                            Layout.topMargin: 6
                            Layout.bottomMargin: 6

                            Repeater {
                                model: 7
                                Rectangle {
                                    width: 60; height: 40; radius: 3; color: c15
                                    Column {
                                        anchors.centerIn: parent; spacing: 2
                                        Text { text: (minorMode ? romanLabelsMin : romanLabels)[index]; color: c50; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                                        Text { text: nn((keyRootSemi() + (minorMode ? minorScaleIv : majorScaleIv)[index]) % 12); color: c80; font.pixelSize: 14; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var scl = minorMode ? minorScaleIv : majorScaleIv;
                                            var dql = minorMode ? diatonicQualsMin : diatonicQuals;
                                            var semi = (keyRootSemi() + scl[index]) % 12;
                                            var nm = nn(semi);
                                            selRoot = nm.charAt(0);
                                            selAcc = (nm.length > 1 && nm.charAt(1) === '#') ? 1 : (nm.length > 1 ? -1 : 0);
                                            selQual = dql[index];
                                            selVoice = 0;
                                            buildChord();
                                        }
                                    }
                                }
                            }
                        }

                        // Degree bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 65
                            color: c10
                            radius: 3

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 20

                                Column {
                                    spacing: 2
                                    Text { text: "DEGREE"; color: c40; font.pixelSize: 10; font.letterSpacing: 2; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                                    Text { text: roman || "-"; color: cW; font.pixelSize: 32; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                                Rectangle { width: 1; height: 42; color: c25 }
                                Column {
                                    spacing: 2
                                    Text { text: "QUALITY"; color: c40; font.pixelSize: 10; font.letterSpacing: 2; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                                    Text { text: getQualityLabel(selQual); color: c60; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                                Rectangle { width: 1; height: 42; color: c25 }
                                Column {
                                    spacing: 2
                                    Text { text: "KEY"; color: c40; font.pixelSize: 10; font.letterSpacing: 2; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                                    Text {
                                        text: {
                                            if (minorMode) return getRelativeMinor(curKey).replace("m","") + " min";
                                            return curKey + " maj";
                                        }
                                        color: c60; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══ RIGHT: ANALYSIS (two columns) ═══
                RowLayout {
                    Layout.preferredWidth: 220
                    Layout.fillHeight: true
                    spacing: 6

                    // ─── Column 1: Sequence + Next + Cadences ───
                    Rectangle {
                        Layout.preferredWidth: 245
                        Layout.fillHeight: true
                        color: c05
                        radius: 3

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 8
                            contentHeight: rightCol1.height
                            clip: true
                            flickableDirection: Flickable.VerticalFlick

                            Column {
                                id: rightCol1
                                width: parent.width
                                spacing: 5

                                // SEQUENCE
                                MouseArea {
                                    width: parent.width; height: 18; cursorShape: Qt.PointingHandCursor
                                    onClicked: pSeqOpen = !pSeqOpen
                                    Row { spacing: 4; Text { text: pSeqOpen ? "v" : ">"; color: c50; font.pixelSize: 14 } Text { text: "SEQUENCE" + (seqChords.length > 0 ? " (" + seqChords.length + ")" : ""); color: c40; font.pixelSize: 13; font.letterSpacing: 2; font.bold: true } }
                                }
                                Column {
                                    visible: pSeqOpen; width: parent.width; spacing: 2
                                    Text { visible: seqChords.length === 0; text: "Press ANALYZE to read\nselected measures"; color: c40; font.pixelSize: 12; wrapMode: Text.WordWrap }
                                    Flow {
                                        width: parent.width; spacing: 3
                                        Repeater {
                                            model: seqChords.length
                                            Rectangle {
                                                width: Math.max(44, sqTxt.width + 14); height: 38; radius: 2; color: c15
                                                Column {
                                                    anchors.centerIn: parent; spacing: 0
                                                    Text { id: sqTxt; text: seqChords[index].roman; color: cW; font.pixelSize: 14; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                                                    Text { text: seqChords[index].name; color: c50; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                                                    Text { text: "c." + (seqChords[index].measure + 1); color: c40; font.pixelSize: 9; anchors.horizontalCenter: parent.horizontalCenter }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        var ch = seqChords[index]; var nm = nn(ch.root);
                                                        selRoot = nm.charAt(0); selAcc = (nm.length > 1 && nm.charAt(1) === '#') ? 1 : (nm.length > 1 ? -1 : 0);
                                                        selQual = ch.quality; selVoice = 0; buildChord();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: c25 }

                                // NEXT CHORD
                                MouseArea {
                                    width: parent.width; height: 18; cursorShape: Qt.PointingHandCursor
                                    onClicked: pNextOpen = !pNextOpen
                                    Row { spacing: 4; Text { text: pNextOpen ? "v" : ">"; color: c50; font.pixelSize: 14 } Text { text: "NEXT CHORD"; color: c40; font.pixelSize: 13; font.letterSpacing: 2; font.bold: true } }
                                }
                                Column {
                                    visible: pNextOpen; width: parent.width; spacing: 2
                                    Text { visible: nextSuggestions.length === 0; text: "Analyze a sequence first"; color: c40; font.pixelSize: 12 }
                                    Repeater {
                                        model: nextSuggestions.length
                                        Rectangle {
                                            width: parent.width; height: 36; radius: 2; color: c10
                                            RowLayout {
                                                anchors.fill: parent; anchors.margins: 4; spacing: 4
                                                Rectangle { width: 3; height: 18; radius: 1; color: Qt.rgba(1, 1, 1, nextSuggestions[index].weight / 50); Layout.alignment: Qt.AlignVCenter }
                                                Column {
                                                    spacing: 0; Layout.fillWidth: true
                                                    Row { spacing: 4; Text { text: nextSuggestions[index].roman; color: cW; font.pixelSize: 15; font.bold: true } Text { text: nextSuggestions[index].chord; color: c60; font.pixelSize: 13 } }
                                                    Text { text: nextSuggestions[index].reason; color: c40; font.pixelSize: 11 }
                                                }
                                                Text { text: nextSuggestions[index].weight + "%"; color: c50; font.pixelSize: 12; Layout.alignment: Qt.AlignVCenter }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var sg = nextSuggestions[index]; var nm = nn(sg.semi);
                                                    selRoot = nm.charAt(0); selAcc = (nm.length > 1 && nm.charAt(1) === '#') ? 1 : (nm.length > 1 ? -1 : 0);
                                                    selQual = sg.qual; selVoice = 0; buildChord();
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: c25 }

                                // CADENCES
                                MouseArea {
                                    width: parent.width; height: 18; cursorShape: Qt.PointingHandCursor
                                    onClicked: pCadOpen = !pCadOpen
                                    Row { spacing: 4; Text { text: pCadOpen ? "v" : ">"; color: c50; font.pixelSize: 14 } Text { text: "CADENCES" + (detectedCadences.length > 0 ? " (" + detectedCadences.length + ")" : ""); color: c40; font.pixelSize: 13; font.letterSpacing: 2; font.bold: true } }
                                }
                                Column {
                                    visible: pCadOpen; width: parent.width; spacing: 2
                                    Repeater {
                                        model: detectedCadences.length
                                        Rectangle {
                                            width: parent.width; height: dcC.height + 6; radius: 2; color: c15; border.color: c30; border.width: 1
                                            Column {
                                                id: dcC; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 5; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                                Text { text: detectedCadences[index].name; color: c90; font.pixelSize: 13; font.bold: true }
                                                Text { text: detectedCadences[index].degrees; color: cW; font.pixelSize: 14 }
                                                Text { text: detectedCadences[index].pos; color: c40; font.pixelSize: 11 }
                                            }
                                        }
                                    }
                                    Text { visible: detectedCadences.length === 0; text: "No cadences detected"; color: c40; font.pixelSize: 12 }
                                }
                            }
                        }
                    }

                    // ─── Column 2: Mood + Reference ───
                    Rectangle {
                        Layout.preferredWidth: 245
                        Layout.fillHeight: true
                        color: c05
                        radius: 3

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 8
                            contentHeight: rightCol2.height
                            clip: true
                            flickableDirection: Flickable.VerticalFlick

                            Column {
                                id: rightCol2
                                width: parent.width
                                spacing: 5

                                // MOOD
                                MouseArea {
                                    width: parent.width; height: 18; cursorShape: Qt.PointingHandCursor
                                    onClicked: pMoodOpen = !pMoodOpen
                                    Row { spacing: 4; Text { text: pMoodOpen ? "v" : ">"; color: c50; font.pixelSize: 14 } Text { text: "MOOD" + (detectedMood.length > 0 ? " : " + detectedMood : ""); color: c40; font.pixelSize: 13; font.letterSpacing: 2; font.bold: true } }
                                }
                                Column {
                                    visible: pMoodOpen; width: parent.width; spacing: 2
                                    Repeater {
                                        model: 8
                                        Rectangle {
                                            property var mData: getMoodFingerprints()[index]
                                            width: parent.width; height: mCol2.height + 8; radius: 2
                                            color: detectedMood === mData.name ? c20 : c10
                                            border.color: detectedMood === mData.name ? c50 : "transparent"; border.width: 1
                                            Column {
                                                id: mCol2; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 5; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                                Row {
                                                    spacing: 4
                                                    Text { text: mData.icon; font.pixelSize: 14; color: c60 }
                                                    Text { text: mData.name; color: detectedMood === mData.name ? cW : c70; font.pixelSize: 13; font.bold: true }
                                                    Text { visible: detectedMood === mData.name; text: "<-"; color: c50; font.pixelSize: 11 }
                                                }
                                                Text { text: mData.chords; color: c60; font.pixelSize: 13 }
                                                Text { text: mData.desc; color: c40; font.pixelSize: 11; wrapMode: Text.WordWrap; width: parent.width }
                                            }
                                        }
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: c25 }

                                // REFERENCE
                                MouseArea {
                                    width: parent.width; height: 18; cursorShape: Qt.PointingHandCursor
                                    onClicked: pRefOpen = !pRefOpen
                                    Row { spacing: 4; Text { text: pRefOpen ? "v" : ">"; color: c50; font.pixelSize: 14 } Text { text: "REFERENCE"; color: c40; font.pixelSize: 13; font.letterSpacing: 2; font.bold: true } }
                                }
                                Column {
                                    visible: pRefOpen; width: parent.width; spacing: 2
                                    Repeater {
                                        model: 10
                                        Rectangle {
                                            property var rData: getRefCadences()[index]
                                            width: parent.width; height: rfCol2.height + 6; radius: 2; color: c10
                                            Column {
                                                id: rfCol2; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 5; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                                Text { text: rData.n; color: c80; font.pixelSize: 13; font.bold: true }
                                                Text { text: rData.d; color: cW; font.pixelSize: 14 }
                                                Text { text: rData.x; color: c40; font.pixelSize: 11; wrapMode: Text.WordWrap; width: parent.width }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    onRun: {
        console.log("Chord Ghost v4.1");
        buildChord();
    }
}
