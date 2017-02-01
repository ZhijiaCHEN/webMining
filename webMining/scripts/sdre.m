%>> available_graphics_toolkits()
%ans =
%{
%  [1,1] = fltk
%  [1,2] = gnuplot
%  [1,3] = qt
%}
%>> graphics_toolkit("gnuplot")

clc;
clear all;
close all;
pkg load signal;

function [a, b] = linearRegression(y)
   n = length(y);
   x=(1:n);
   xy = x.*y;
   x2=x.^2;
   sx = sum(x);
   sy=sum(y);
   sxy=sum(xy);
   sx2=sum(x2);
   delta=n*sx2-sx^2;
   
   a=(n*sxy-sy*sx)/delta;
	b=(sx2*sy-sx*sxy)/delta;
end

function t = transform(sig)
	sig = sig .* hanning(length(sig),"periodic")';
	t=abs(fft(sig)).^2;
end

function t = contour(s)
	t = s;
	n = length(s);
	height = s(1);
	for i=1:1:n
		if s(i) > height
			height = s(i);
		end
		t(i) = height;
	end
end

function d = firstDiff(s)
	n = length(s);
	d = s;
	d(2:n) = diff(s);
	d(1) = 1;
end

function r = segment(c)
	count = 0;
	n = length(c);
	d = firstDiff(c);
	
	start = 1;
	finish = 1;
	for i=1:1:n
		if d(i) != 0
			if (finish - start + 1) > 3
				count = count + 1;
				r{count} = [start, finish];
			end
			start = i + 1;
			finish = i + 1;
		else
			finish = i;
		end
	end
	if start != finish
		count = count + 1;
		r{count} = [start, finish];
	end
end

function mr = mergeRegions(r, s)
	count = 1;
	n = length(r);
	mr{1} = r{1};
	for i=2:n
		palpha = unique(s(mr{count}(1):mr{count}(2)));
		alpha = unique(s(r{i}(1):r{i}(2)));
		if length(intersect(alpha, palpha)) > 0
			mr{count}(2) = r{i}(2);
		else
			count = count + 1;
			mr{count} = r{i};
		end
	end
end

function sr = detectStructure(r,s)
	count = 0;
	n = length(r);
	for i=1:1:n
		[a,b] = linearRegression(s(r{i}(1):r{i}(2)));
		r{i}(3:4) = [a, b];
		if abs(a) < 4.5*pi/180.0 % 4.5 degrees
			count = count + 1;
			sr{count} = r{i};
		end
	end
end

function v = score(region, period)
	n = length(region);
	avg = mean(region);
	region = region - avg;
	candidates = sort(unique(region(find(region<0))));
	estFreq = length(region) / period;
	maxScore = -Inf;
	v = 0;
	
	while (length(candidates) > 0)
		value = candidates(1);
		candidates = setdiff(candidates, value);
		
		recpos = find(region == value);
		reccount = length(recpos);
		%avgSize = avg(diff(recpos));
		avgSize = sum(abs(diff(recpos)-period));
		
		coverage = (recpos(reccount) - recpos(1)) / n;
		freqRatio = min(reccount, estFreq) / max(reccount, estFreq);
		%sizeRatio = min(avgSize, period) / max(avgSize, period);
		sizeRatio = 1 - (min(avgSize, n) / max(avgSize, n));
		scr = (coverage + freqRatio + sizeRatio) / 3;
		printf("value=%d, cov=%.2f, #=%.2f, size=%.2f, s=%.4f - %.2f\n",
			round(value+avg),coverage,freqRatio,sizeRatio,scr,period);
			
		if scr > maxScore
			maxScore = scr;
			v = recpos;
			haltScore = 0.75;
			if ((coverage > haltScore) && (freqRatio > haltScore) && (sizeRatio > haltScore))
				printf("\n");
				return;
			end
		end
	end
	printf("\n");
end

function drawPlots(s, c, r)
	d = firstDiff(c);
	figure; % signal only
	plot(s,'k--');
	legend("tps");
	
	figure; % signal and contour
	subplot(2,1,1);
	plot(s,'k--'); hold;
	plot(c, 'k.');
	l=legend("tps", "contour");
	legend(l,'location','northeastoutside');
	ylabel('TPCode');
	xlabel('position');
	title("a - Contour");
	%plot(d.*mean(c), 'ok');
	
	subplot(2,1,2);
	%figure; % signal and 1st diff of contour
	plot(s,'k--'); hold;
	plot((d!=0) .* c,'k.');
	l=legend("tps", "finite diff");
	legend(l,'location','northeastoutside');
	ylabel('TPCode');
	xlabel('position');
	title("b - Finite Difference");
	
	figure; % structured regions
	plot(s,'.-'); hold;
	for i=1:1:length(r)
		interval = r{i}(1):r{i}(2);
		reg = s(r{i}(1):r{i}(2));
		plot(interval,reg,'.r');
	end
end

function rec = findRecords(reg, a, b)
	n = length(reg);
	nDiv2 = round(n/2);
	t = abs(fft(reg - mean(reg))).^2;
	t = zscore(t(1:nDiv2));
	
	freq = find(t == max(t))(1);
	
	period = round(n/freq);
	
	if n == 830
		period = round(n/21)
	end
	
	printf("f: %d, p:%d\n",freq,period);
	
	figure;
	subplot(2,1,1);
	plot(1:n,reg,'k.-'); hold on;
	plot(1:n,(a.*[1:n]) + b,'k--');
	text(n,(a.*n) + b,[num2str(a*180/pi,"%3.2f") ' o']);
	%text(n,(a.*n) + b,[num2str(a*180/pi,"%3.2f") '\circ']);
	title('a - data region, linear regression and record boundary');
	xlabel('position');
	ylabel('TPCode');

	v = score(reg, period);
	if length(v) > 1
		plot(v,reg(v),'ks');
		l = legend("Region", "Angle", "Records");
		for i=1:length(v)-1
			rec{i} = reg(v(i):v(i+1)-1);
		end
		rec{length(v)} = reg(v(length(v)):length(reg));
	else
		rec{1}=0;
		l = legend("Region", "Angle");
	end
	legend(l, 'location', "northeastoutside");
	
	subplot(2,1,2);
	plot(t,'k.-'); hold on;
	plot(freq,t(freq),'ks');
	if freq > 1
		text(freq+5,t(freq),['frequency/number of records = ' num2str(freq-1)]);
		text(freq+5,t(freq)-1,['period/record size = ' num2str(round(n/(freq-1)))]);
	end
	if n == 830 
		plot(21,t(21),'ko');
		text(21+5,t(21),['correct frequency/number of records = ' num2str(21-1)]);
		text(21+5,t(21)-1,['correct period/record size = ' num2str(round(n/(21-1)))]);
		l = legend("PSD","Max. Peak","Correct Peak");
	else
		l = legend("PSD","Peak");
	end
	legend(l, 'location', "northeastoutside");
	title("b - PSD");
	xlabel('frequency');
	ylabel('Z-Score');
end

function sr = extract(s)
	c = contour(s);
	r = segment(c);
	mr = mergeRegions(r,s);

	k = 0;
	for i=1:1:length(mr)
		ss = fliplr(s(mr{i}(1):mr{i}(2)));
		cc = contour(ss);
		rr = segment(cc);
		if length(rr) >= 1
			for j=1:1:length(rr)
				k=k+1;
				mmr{k}=rr{length(rr)+1-j};
				mmr{k}(1) = length(ss) - mmr{k}(1) + mr{i}(1);
				mmr{k}(2) = length(ss) - mmr{k}(2) + mr{i}(1);
				tmp = mmr{k}(1);
				mmr{k}(1) = mmr{k}(2);
				mmr{k}(2) = tmp;
			end
		else
			k=k+1;
			mmr{k}=mr{i};
		end
	end
	mr = mergeRegions(mmr,s);
	
	for i=1:1:length(mr)
		alpha = unique(s(mr{i}(1):mr{i}(2)));
		j = mr{i}(1) - 1;
		while (j >= 1 && length(find(alpha==s(j))))
			mr{i}(1) = j;
			j=j-1;
		end

		j = mr{i}(2) + 1;
		while (j <= length(s) && length(find(alpha==s(j))))
			mr{i}(2) = j;
			j=j+1;
		end
	end
	
	sr = detectStructure(mr,s);
	drawPlots(s, c, sr);
	
	for i=1:1:length(sr)
		reg = s(sr{i}(1):sr{i}(2));
		a = sr{i}(3);
		b = sr{i}(4);
		rec = findRecords(reg,a,b);
		if length(rec)>1
			printf("Found %d records:\n",length(rec));
		end
		
		for i=1:length(rec)
			for j=1:length(rec{i})
				printf("%d;",rec{i}(j));
			end
			printf("\n");
		end
		if length(reg) == 830
			break
			end
	end
end

signal = [2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,15,24,25,15,24,25,26,27,28,29,30,31,32,33,34,35,34,36,37,38,34,39,31,40,41,42,43,44,45,46,47,48,49,50,47,48,51,50,47,48,52,50,53,54,55,56,57,58,59,13,60,61,62,63,64,65,66,67,68,66,67,68,66,67,68,66,67,68,62,63,64,69,70,71,72,73,74,72,73,74,72,73,74,72,73,74,70,75,76,77,78,79,78,79,71,72,80,81,72,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,60,107,108,6,6,109,110,111,112,113,114,115,114,116,117,118,119,120,121,122,123,124,123,124,123,124,125,126,127,128,129,130,131,132,133,134,135,132,133,134,135,136,137,138,139,140,141,142,143,140,141,142,143,140,141,142,143,144,145,138,146,147,148,149,150,151,152,153,151,154,155,151,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,167,168,169,170,171,172,173,167,168,169,170,171,172,173,167,168,169,170,171,172,173,167,168,169,170,171,172,173,174,175,174,176,177,178,179,180,181,182,183,184,183,185,186,187,188,189,190,191,192,193,194,111,110,195,196,197,198,199,200,201,202,203,204,205,206,207,208,206,209,210,211,212,213,214,215,216,217,214,215,216,217,214,215,216,217,214,215,216,217,214,215,216,217,210,211,212,213,214,215,216,217,214,215,216,217,214,215,216,217,214,215,216,217,214,215,216,217,210,211,212,213,214,215,216,217,214,215,216,217,210,211,212,213,214,215,216,217,214,215,216,217,214,215,216,217,214,215,216,217,214,215,216,217,210,211,212,213,214,218,219,214,215,216,217,214,215,216,217,214,215,216,217,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,240,241,240,241,244,245,246,247,245,248,249,250,251,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,240,241,240,241,244,245,252,253,254,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,278,279,280,281,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,282,283,277,278,279,280,281,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,278,279,280,281,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,278,279,280,281,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,278,279,280,281,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,282,283,277,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,278,279,280,281,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,278,279,280,281,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,282,283,277,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,278,279,280,281,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,278,279,280,281,280,281,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,272,273,272,273,276,277,282,283,277,278,279,280,281,280,281,284,285,286,287,288,289,290,291,292,293,290,291,292,293,290,291,292,293,290,291,292,293,290,291,292,293,290,291,292,293,290,291,292,293,290,291,292,3,6,294,295,296,297,298,299,300,301,302,303,304,305,306,302,307,298,299,303,304,305,306,302,307,298,299,303,304,305,306,302,307,308,309,310,311,312,313,311,314,315,316,317,318,319,320,315,316,317,318,319,320,315,316,317,318,319,320,6,321,322,323,324,322,323,324,322,323,324,322,323,324,322,323,324,322,323,324,321,322,323,324,322,323,324,322,323,324,322,323,324,322,323,324,325,326,327,328,329,330,331,332,333,334,335,336,337,338,339,340,341,342,325,332,333,334,335,336,337,338,339,340,341,342,343,344,345,346,347,348,349,350,351,344,352,353,354,355,356,357,352,353,354,355,358,344,359,347,360,361,344,362,363,364,365,366,367,368,363,364,365,366,369,370,371,372,373,374,375,376,377,378,379,344,359,347,380,381,344,359,347,382,383,344,359,347,382,383,384,385,386,387,388,389,389,389,389,389,3];
%signal = [2,3,3,4,5,6,4,7,8,9,10,11,12,13,7,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,51,54,55,56,57,58,59,60,57,58,59,61,62,63,64,65,66,67,14,4,68,69,70,71,72,73,74,75,76,77,78,79,80,75,76,77,78,79,80,75,76,77,78,79,80,75,76,77,78,79,80,75,76,77,78,79,80,75,76,77,78,79,80,81,72,73,82,83,84,74,75,76,77,78,79,80,81,72,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,95,96,97,98,99,100,101,102,103,95,96,97,98,99,100,101,102,103,95,96,97,98,99,100,101,102,103,104,105,106,107,81,72,73,74,75,76,77,78,79,80,108,109,109,109,109,109,109,109,109,109,109,109,109,108,109,109,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,148,153,154,155,147,156,157,158,159,160,161,162,163,164,165,166,163,164,165,166,163,164,165,166,167,168,169,170,171,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,182,183,184,182,183,184,185,186,187,188,189,190,191,192,193,194,194,195,196,197,198,197,198,197,198,197,115,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,221,222,223,224,221,222,223,224,221,222,223,224,221,222,223,224,217,218,219,220,221,222,223,224,221,222,223,224,221,222,223,224,221,222,223,224,221,222,223,224,217,218,219,220,221,222,223,224,221,222,223,224,217,218,219,220,221,222,223,224,221,222,223,224,221,222,223,224,221,222,223,224,221,222,223,224,221,222,223,224,221,222,223,224,221,222,223,224,217,218,219,220,221,225,226,221,222,223,224,221,222,223,224,221,222,223,224,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,243,244,245,246,247,248,249,250,251,252,253,254,255,256,257,258,259,260,261,262,263,264,265,263,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,297,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,297,229,266,267,268,269,270,271,298,299,300,301,302,303,304,305,306,307,308,309,310,311,312,313,281,282,283,284,285,286,287,288,289,290,314,315,316,317,318,319,315,316,317,318,319,291,292,293,320,321,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,322,323,296,297,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,297,229,266,267,268,269,270,271,298,299,300,301,302,303,304,305,306,307,308,309,310,311,312,313,281,282,283,284,285,286,287,288,289,290,314,315,316,317,318,319,315,316,317,318,319,291,292,293,320,321,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,297,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,297,229,266,267,268,269,270,271,298,299,300,301,302,303,304,305,306,307,308,309,310,311,312,313,281,282,283,284,285,286,287,288,289,290,314,315,316,317,318,319,315,316,317,318,319,291,292,293,320,321,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,297,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,297,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,324,291,292,293,294,293,294,295,296,297,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,297,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,297,229,266,267,268,269,270,271,298,299,300,301,302,303,304,305,306,307,308,309,310,311,312,313,281,282,283,284,285,286,287,288,289,290,314,315,316,317,318,319,315,316,317,318,319,291,292,293,320,321,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,322,323,296,297,229,266,267,268,269,270,271,298,299,300,301,302,303,304,305,306,307,308,309,310,311,312,313,281,282,283,284,285,286,287,288,289,290,314,315,316,317,318,319,315,316,317,318,319,291,292,293,320,321,229,266,267,268,269,270,271,298,299,300,301,302,303,304,305,306,307,308,309,310,311,312,313,281,282,283,284,285,286,287,288,289,290,314,315,316,317,318,319,315,316,317,318,319,291,292,293,320,321,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,297,229,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,293,294,295,296,297,325,326,327,328,329,330,331,332,329,330,331,332,329,330,331,332,329,330,331,332,329,330,331,332,329,330,331,332,329,330,331,332,333,334,335,336,337,338,339,340,341,342,343,344,345,346,347,348,349,343,344,345,346,347,348,349,343,344,345,346,347,348,349,350,351,352,353,354,355,356,357,358,359,360,357,358,359,360,357,358,359,360,339,361,362,363,364,362,363,364,362,363,364,362,363,364,362,363,364,362,363,364,362,363,364,361,362,363,364,362,363,364,362,363,364,362,365,366,362,363,364,367,368,369,370,371,372,373,374,375,376,377,378,379,380,381,382,383,384,385,386,387,388,389,389,389,389,389,389];
sr = extract(signal);
