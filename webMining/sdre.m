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

function r = regions(c)
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
	for i=2:1:n
		palpha = unique(s(mr{count}(1):mr{count}(2)));
		alpha = unique(s(r{i}(1):r{i}(2)));
		if length(intersect(alpha, palpha)) > 0
			mr{count}(2) = r{i}(2);
		else
			count = count + 1;
			mr{count} = r{i};
		end
	end
	
	n = length(s);
	for i=1:1:length(mr)
		alpha = unique(s(mr{i}(1):mr{i}(2)));
		while (mr{i}(1) > 1) && (length(intersect(s(mr{i}(1)-1),alpha)) > 0)
			mr{i}(1) = mr{i}(1) - 1;
		end
		
		while (mr{i}(2) < n) && (length(intersect(s(mr{i}(2)+1),alpha)) > 0)
			mr{i}(2) = mr{i}(2) + 1;
		end
	end
end

function sr = detectStructure(r,s)
	count = 0;
	n = length(r);
	for i=1:1:n
		a = linearRegression(s(r{i}(1):r{i}(2)));
		if abs(a) < 0.17633 % 10 degrees
			count = count + 1;
			sr{count} = r{i};
		end
	end
end

function drawPlots(s, c, r)
	d = firstDiff(c);
	figure; % signal only
	plot(s,'.-');
	
	figure; % signal and contour
	plot(s,'.-'); hold;
	plot(c, '.r');
	%plot(d.*mean(c), 'ok');
	
	figure; % signal and 1st diff of contour
	plot(s,'.-'); hold;
	plot((d!=0) .* c,'.r');
	
	figure; % structured regions
	plot(s,'.-'); hold;
	for i=1:1:length(r)
		plot(r{i}(1):r{i}(2),s(r{i}(1):r{i}(2)),'.r');
	end
end

function sr = segment(s)
	c = contour(s);
	r = regions(c);
	mr = mergeRegions(r,s);
	sr = detectStructure(mr,s);
	drawPlots(s, c, sr);
end

function t = transform(sig)
	size = length(sig);
	lowpass(1:size) = 1/size;
	%lowpass(ceil(size/8):size)=0;
	
	sig = real(ifft(fft(sig).*lowpass));
	
	sig = sig .* welchwin(length(sig),"periodic")';
	t=abs(fft(sig)).^2;
end

function a = linearReg(sig)
	l = length(sig);
	x = [1:l]';
	y = sig';
	X = [ones(l,1) x];
	a = (pinv(X'*X))*X'*y;
end

function p = symfil(sig,f)
	p{1}=[1 length(sig)];
	[a,b] = hist(sig,unique(sig));
	
	c = find(a<=f);
	z = zeros(length(sig),1);
	for i=1:length(sig)
		if sum(c==sig(i))!=0
			z(i)=1;
		end
	end

	s=1;e=1;c=0;j=1;
	for i=1:length(sig)
		if c==0
			s=s+1;
			if z(i)==0
				c=1;
				e=s;
			end
		end
		if c==1 
			if z(i)==0
				e=e+1;
			else
				e=i-1;
				if e-s > 3
					reg = sig(s:e); %-mean(sig(s:e)); %regiao 
					alphabet=unique(reg); % alfabeto da regiao
					if j>1
						if length(intersect(alphabet,ab{j-1})) > 0
							p{j-1}(2)=e;
							r{j-1}= sig(p{j-1}(1):e); %-mean(sig(p{j-1}(1):e));
							ab{j-1}=union(ab{j-1},alphabet);
							c=0;
							s=i;
							printf("merge r{%d} + r{%d} [%d %d]\n",j-1,j,p{j-1}(1),p{j-1}(2));
							continue;
						end
					end
					r{j}= reg;
					p{j}=[s e]; %posicao original 
					ab{j}=alphabet;
					j=j+1;
				end
				c=0;
				s=i;
			end
		end
	end
end

function [p,d] = findPeaks(s)
	size = length(s);
	
	q = s;
	%q(find(q<0))=-1;
	%q(find(q>0))=+1;
	
	d1 = diff(q,1);
	d1 = d1<0;
	d1 = d1.* s(2:size);
	p = find(d1<0);
	d = d1(p);
	p = p+1;
	
	p = find(s<0);
	d = s(p);
end

function v=score(p,d,s,f)
	size = length(s);
	candidates = unique(d);
	printf("\n");
	maxScore = -Inf;
	v=-Inf;
	
	while length(candidates) > 0
		value = min(candidates);
		candidates = setdiff(candidates,value);
		pos = find(d==value);
		reccount = length(pos);
		if reccount>1
			recsize = diff(p(pos));
			dev=std(recsize);
			m=mean(recsize);
			%coverage=((p(pos(length(pos)))-p(pos(1)))/size);%-coefVar;
			regionCoverage = min([m*reccount/size 1]);
			rcountRatio = (min([reccount size/m])/max([reccount size/m]));
			if dev>1
				rsizeRatio = (min([m/dev f])/max([m/dev f]));
			else
				rsizeRatio = (min([m f])/max([m f]));
			end
			tpcRatio = abs(value)/max(abs(s));
			scr = (regionCoverage+rcountRatio+rsizeRatio+tpcRatio)/4;
			if scr > maxScore
				maxScore = scr;
				v=value;
			end
			printf("value=%.2f, cov=%.2f, #=%.2f, size=%.2f, t=%.2f, s=%.4f - %d\n",value,regionCoverage,rcountRatio,rsizeRatio,tpcRatio,scr,f);
		end
	end
end

function q = reencode(s)
	setCodes = unique(s);
	
	pos = 1; n=1;
	while pos<=length(s)
		if find(setCodes==s(pos))
			c{s(pos)}=n;
			setCodes = setdiff(setCodes,s(pos));
			q(pos)=n;
			n=n+1;
		else
			q(pos)=c{s(pos)};
		end
		pos = pos+1;
	end
	q = s;
end

%s = [2,3,4,5,6,7,5,8,9,9,9,9,9,9,9,10,11,9,5,12,13,14,5,6,7,5,15,16,17,18,19,20,17,18,19,20,17,18,19,20,17,18,19,20,17,18,19,21,5,22,23,24,25,26,27,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,28,29,30,31,30,25,27,28,29,28,29,30,32,33,34,35,36,37,38,35,22,39,40,5,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,56,63,64,65,66,67,68,69,70,71,72,73,74,75,76,74,75,76,74,75,76,74,75,76,74,77,78,79,80,81,79,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,84,101,102,103,104,105,106,107,108,109,107,108,109,107,108,109,107,108,110,111,112,113,114,104,115,116,117,118,119,120,118,119,116,117,120,104,121,122,84,123,124,125,126,127,84,128,129,130,131,131,131,82,83,84,85,86,132,88,89,90,91,92,93,94,95,96,97,98,99,100,84,101,102,103,104,105,106,107,108,109,107,108,110,111,112,113,114,104,115,116,117,118,119,120,118,119,116,117,120,104,121,122,84,123,124,125,126,127,84,128,129,130,131,131,131,82,83,84,85,86,133,88,89,90,91,92,93,94,95,96,97,98,99,100,84,101,102,103,104,105,106,107,108,109,107,108,109,107,108,109,107,108,110,111,112,113,114,112,113,114,104,115,116,117,118,119,120,118,119,116,117,120,104,121,122,84,123,124,125,126,127,84,128,129,130,131,131,131,82,83,84,85,86,134,88,89,90,91,92,93,94,95,96,97,98,99,135,136,84,101,102,103,104,105,106,107,108,109,107,108,109,107,108,109,107,108,110,111,112,113,114,112,113,114,104,115,116,117,118,119,120,118,119,116,117,120,104,121,122,84,123,124,125,126,127,84,128,129,130,131,131,131,82,83,84,85,86,137,88,89,90,91,92,93,94,95,96,97,98,99,100,84,101,102,103,104,105,106,107,108,109,107,108,109,107,108,109,107,108,110,111,112,113,114,104,115,116,117,118,119,120,118,119,116,117,120,104,121,122,84,123,124,125,126,127,84,128,129,130,131,131,131,82,83,84,85,86,132,88,89,90,91,92,93,94,95,96,97,98,99,100,84,101,102,103,104,105,106,107,108,109,107,108,109,107,108,109,107,108,110,111,112,113,114,112,113,114,104,115,116,117,118,119,120,118,119,116,117,120,104,121,122,84,123,124,125,126,127,84,128,129,130,131,131,131,82,83,84,85,86,138,88,89,90,91,92,93,94,95,96,97,98,99,100,84,101,102,103,104,105,106,107,108,109,107,108,109,107,108,109,107,108,110,111,112,113,114,104,115,116,117,118,119,120,118,119,116,117,120,104,121,122,84,123,124,125,126,127,84,128,129,130,131,131,131,82,83,84,85,86,139,88,89,90,91,92,93,94,95,96,97,98,99,135,136,84,101,102,103,104,105,106,107,108,109,107,108,109,107,108,110,111,112,113,114,112,113,114,104,115,116,117,118,119,120,118,119,116,117,120,104,121,122,84,123,124,125,126,127,84,128,129,130,131,131,131,82,83,84,85,86,133,88,89,90,91,92,93,94,95,96,97,98,99,100,84,101,102,103,104,105,106,107,108,109,107,108,109,107,108,109,107,108,110,111,112,113,114,104,115,116,117,118,119,120,118,119,116,117,120,104,121,122,84,123,124,125,126,127,84,128,129,130,131,131,131,82,83,84,85,86,140,88,89,90,91,92,93,94,95,96,97,98,99,100,84,101,102,103,104,105,106,107,108,109,107,108,110,111,112,113,114,112,113,114,104,115,116,117,118,119,120,118,119,116,117,120,104,121,122,84,123,124,125,126,127,84,128,129,68,69,70,71,72,73,74,75,76,74,75,76,74,75,76,74,75,76,74,77,78,79,80,81,79,141,53,3,4,5,22,142,143,144,145,144,145,146,147,148,149,150,151,144,152,153,154,155,156,157,154,155,156,157,154,155,156,157,154,155,156,144,152,158,159,160,161,162,163,144,145,164,164,164,164,164,164];
signal=[1,2,3,4,5,6,7,8,9,10,11,10,11,10,11,10,11,10,11,12,13,14,15,16,5,6,7,17,17,18,19,20,21,22,23,24,19,25,26,27,28,29,30,31,32,33,34,35,36,37,37,34,35,36,37,37,34,35,36,37,37,34,35,36,37,37,34,35,36,37,37,34,35,36,37,37,34,35,36,37,37,34,35,36,37,37,34,35,36,37,37,38,39,40,38,38,38,38,41,42,43,44];

figure; plot(signal);

p = segment(signal);

sig(1:length(signal))=0;
for i=1:length(p)
	r{i} = reencode(signal(p{i}(1):p{i}(2)));
	r{i} = r{i} - mean(r{i});
	sig(p{i}(1):p{i}(2)) = r{i};

	l{i} = linearReg(r{i});
	ffts{i}=transform(r{i});

	angle = atand(abs(l{i}(2)));

	if angle < 5
		figure; hold on; 

		size = length(r{i});
		Sdiv2 = ceil(size/4);
		pos = find( ffts{i}(3:Sdiv2-1)==max(ffts{i}(3:Sdiv2-1)) );
		if length(pos > 1)
			pos=pos(1);
			plotPeriod=1;
		else
			plotPeriod=0;
		end
		period = 1;%round(size / pos);
		
		subplot(1,2,1);
		plot(1:size,r{i},'.-'); hold on;
		text(size,max(r{i}),num2str(std(r{i})));
		
		[peaks,d1] = findPeaks(r{i});
		value=score(peaks,d1,r{i},period);
		if value!=-Inf
			plot(find(r{i}==value),r{i}(find(r{i}==value)),'rx');
		end
		%plot(3:size,diff(r{i},2),'g');
		
		plot(1:size,(l{i}(2).*[1:size]) + l{i}(1),'k');
		text(size,(l{i}(2).*size) + l{i}(1),num2str(angle));
		
		subplot(1,2,2);
		plot(1:Sdiv2,ffts{i}(1:Sdiv2),'.-');
		if plotPeriod==1
			text(pos+1,ffts{i}(pos+1),num2str(period));
		end
	end
end
signal = sig;
%----

signal = signal-mean(signal);
len = length(signal);

figure;
plot(transform(signal)(1:round(len/2)),'.-'); figure;
plot(signal); hold;
return;
