/*
    Copyright 2011 Roberto Panerai Velloso.

    This file is part of libsockets.

    libsockets is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    libsockets is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with libsockets.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef MISC_H_
#define MISC_H_

#include <iostream>
#include <map>
#include <sstream>
#include <cmath>
#include <set>
#include <vector>
#include <tidy.h>
#include "Ckmeans.1d.dp.h"

using namespace std;

#define lowerCase(s) std::transform(s.begin(), s.end(), s.begin(), (int(*)(int))std::tolower)

#define CRLF "\n"

extern vector<double> _fft(vector<double>, int);
extern vector<double> autoCorrelation(vector<double>);

#define fft(X) _fft(X,1)
#define ifft(X) _fft(X,-1)

string &trim(string &);
string stringTok(string &, string);

#define sign(v) ((v<0)?-1:1)

template<typename T>
string to_string(T val) {
	stringstream ss;

	ss << val;
	return ss.str();
}

template<typename T>
float mean(T s) {

	float total=0;

	for (size_t i=0;i<s.size();i++) {
		total += s[i];
	}
	return total/(float)s.size();
}

#define SPACE T(1,'\0')

template <class T>
size_t edit_distance(T &s1, T &s2, bool align, vector<unsigned int> *spaces) {
	const size_t len1 = s1.size(), len2 = s2.size();
	vector<vector<unsigned int> > d(len1 + 1, vector<unsigned int>(len2 + 1));

	d[0][0] = 0;
	for(unsigned int i = 1; i <= len1; ++i) d[i][0] = i;
	for(unsigned int i = 1; i <= len2; ++i) d[0][i] = i;

	for(unsigned int i = 1; i <= len1; ++i) {
		for(unsigned int j = 1; j <= len2; ++j) {
			d[i][j] = min(min(d[i - 1][j] + 1,d[i][j - 1] + 1),
					d[i - 1][j - 1] + (s1[i - 1] == s2[j - 1] ? 0 : 1) );
		}
	}

	if (align) {
		unsigned int i=len1;
		unsigned int j=len2;
		T s11,s22;
		while ((i>0) && (j>0)) {
			if ((d[i-1][j-1] <= d[i-1][j]) && (d[i-1][j-1] <= d[i][j-1])) {
				s11 = s1[i-1] + s11;
				s22 = s2[j-1] + s22;
				i--;
				j--;
			} else if (d[i-1][j] < d[i][j-1]) {
				s11 = s1[i-1] + s11;
				s22 = SPACE + s22;
				i--;
			} else {
				spaces->push_back(i-1);
				s11 = SPACE + s11;
				s22 = s2[j-1] + s22;
				j--;
			}
		}
		s1=s11;
		s2=s22;
	}

	return d[len1][len2];
}

template <class T>
void normalizeSequences(vector<T> &M) {
	vector<double> ckmeansInput;

    ckmeansInput.push_back(0);
	for (size_t i=0;i<M.size();i++) {
		ckmeansInput.push_back(M[i].size());
	}

	ClusterResult result;
    result = kmeans_1d_dp(ckmeansInput,2,2);

    if (result.nClusters == 2) {
    	size_t maxSize=0;

    	if (result.size[1] > result.size[2]) {
			for (size_t i=0;i<M.size();i++) {
				if (result.cluster[i+1] == 1) {
					if (M[i].size() > maxSize)
						maxSize = M[i].size();
				}
			}

			for (size_t i=0;i<M.size();i++) {
				if (M[i].size() > maxSize)
					M[i] = M[i].substr(1,maxSize);
			}
    	}
    }
}

template <class T>
double centerStar(vector<T> &M) {
	size_t ret=0;

	normalizeSequences(M);

	size_t len = M.size();
	vector<vector<unsigned int> > d(len,vector<unsigned int>(len));
	//unsigned int d[len][len];
	size_t minscore=0xffffffff,center=0;

	// find the center string
	size_t score;
	for (size_t i=0;i<len;i++) {
		d[i][i]=0;
		score = 0;
		for (size_t j=i+1;j<len;j++) {
			d[i][j] = edit_distance(M[i],M[j],false,NULL);
			d[j][i] = d[i][j];
			score += d[i][j];
		}
		for (size_t j=0;j<=i;j++) score += d[i][j];
		if (score < minscore) {
			minscore = score;
			center = i;
		}
	}

	// align
	for (size_t i=0; i<M.size();i++) {
		if (i!=center) {
			vector<unsigned int> spaces;

			ret += edit_distance(M[center],M[i],true,&spaces);
			if (spaces.size()) {
				for (size_t j=i;j>0;j--) {
					if ((j-1)!=center) {
						for (size_t k=0;k<spaces.size();k++) {
							M[j-1].insert(spaces[k],SPACE);
						}
					}
				}
			}
		}
	}

	for (size_t i=0;i<M.size();i++) {
		for (size_t j=0;j<M[i].size();j++)
			cerr << M[i][j] << ";";
		cerr << endl;
	}
	return ((double)M[0].size()*(double)M.size() / (double) max(ret,(size_t)1));
}

struct tLinearCoeff {
	float a,b,e;
};

template <class T>
size_t trimSequence(T &s) {
	float m=0;
	float mul=1;
	size_t ret=0;

	for (size_t i=0;i<s.size();i++)
		m+=s[i];

	m/=(float)(s.size());

	if (s[0] < m) mul=-1;
	for (size_t i=0;i<s.size();i++) {
		if (mul*(s[i]-m) < 0) {
			s.erase(0,i);
			ret = i;
			break;
		}
	}

	if (s[s.size()-1] < m) mul=-1;
	else mul=1;

	for (auto i=s.size()-1;i>0;i--) {
		if (mul*(s[i]-m) < 0) {
			s.erase(i);
			break;
		}
	}
	return ret;
}

template <class T>
tLinearCoeff linearRegression(T s) {
	//trimSequence(s);
	double delta,x,y,xy,x2,sx=0,sy=0,sxy=0,sx2=0,n=s.size();
	tLinearCoeff lc;

	for (long int i=0;i<n;i++) {
		y = s[i];
		x = i;
		xy = x*y;
		x2 = x*x;

		sx += x;
		sy += y;
		sxy += xy;
		sx2 += x2;
	}

	delta = (n*sx2)-(sx*sx);
	lc.a = (double)((double)((n*sxy)-(sy*sx))/(double)delta);
	lc.b = (double)((double)((sx2*sy)-(sx*sxy))/(double)delta);


	for (long int i=0;i<n;i++) {
		double ee;
		ee = abs(s[i] - (lc.a*i + lc.b));
		lc.e += ee*ee;
	}
	lc.e /= n;

	return lc;
}

/*todo: testar alinhamento com swap e com offset.
Arrumar a sequencia de nodos que n�o est� sendo atualizada junto com a sequencia de tags*/

template <class T>
void align(vector<T> &ss) {
	size_t maxSize=0;

	normalizeSequences(ss);

	for (size_t i=0;i<ss.size();i++) {
			if (ss[i].size() > maxSize) maxSize = ss[i].size();
	}
	for (size_t i=0;i<ss.size();i++) {
		ss[i].resize(maxSize); // pad strings to the same size;
	}

	vector<typename T::value_type> profile;
	set<typename T::value_type> symbols;
	symbols.insert((typename T::value_type)0);

	for (size_t j=0;j<maxSize;j++) {
		map<typename T::value_type,size_t> freq;
		size_t maxFreq=0;
		typename T::value_type symbol = ss[0][j];

		for (size_t i=0;i<ss.size();i++) {
			//if (ss[i][j] != (typename T::value_type)0) {
				freq[ss[i][j]]++;
				if ((symbols.find(freq[ss[i][j]]) == symbols.end()) && (freq[ss[i][j]] > maxFreq)) {
					symbol = ss[i][j];
				}
				maxFreq = freq[symbol];
			//}
		}
		profile.push_back(symbol);
		symbols.insert(symbol);
	}

	for (size_t i=0;i<ss.size();i++) {
		for (size_t j=0;j<maxSize;j++) {
			if (ss[i][j] != profile[j]) {
				auto pos = ss[i].find_first_of(profile[j],j+1);
				if (pos != string::npos) {
					typename T::value_type c = ss[i][j];
					ss[i][j] = ss[i][pos];
					ss[i][pos] = c;
				} else {
					pos = ss[i].find_first_of((typename T::value_type)0,j+1);
					if (pos != string::npos) {
						ss[i][pos] = ss[i][j];
						ss[i][j] = (typename T::value_type)0;
					}
				}
			}
		}
	}
}

#endif /* MISC_H_ */
