#!/usr/bin/python3

from statistics import mean
from joblib import dump, load
from sklearn.datasets import load_svmlight_file
from sklearn.preprocessing import StandardScaler
from mlxtend.feature_selection import ColumnSelector
from sklearn.preprocessing import PolynomialFeatures
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.svm import SVC
from sklearn.naive_bayes import GaussianNB
from sklearn.neighbors import KNeighborsClassifier
from xgboost import XGBClassifier
from sklearn.pipeline import Pipeline
from sklearn.metrics import f1_score, precision_score, recall_score, accuracy_score, SCORERS
from sklearn.model_selection import cross_val_score
from sklearn.model_selection import ShuffleSplit

data = load_svmlight_file('dataset.svmlight')
x = data[0].todense()
y = data[1]

model = Pipeline([
('column_selector', ColumnSelector(cols=(0,1,2,3,4,5,6))),
('scaler', StandardScaler()),
('poly', PolynomialFeatures(degree=2)),
('classifier', LogisticRegression(penalty='l2', solver='liblinear'))
#('classifier', GradientBoostingClassifier())
#('classifier', SVC())
#('classifier', GaussianNB())
#('classifier', KNeighborsClassifier(n_neighbors=13))
#('classifier', XGBClassifier(max_depth=3))
])

print(mean(cross_val_score(estimator=model, X=x, y=y, cv=ShuffleSplit(n_splits=400, test_size=0.5), scoring='f1')))

model.fit(x, y)
dump(model, 'classifier.joblib')
y_pred = model.predict(x)
print('accuracy: ', accuracy_score(y, y_pred))
print('f1: ', f1_score(y, y_pred))
print('precision: ', precision_score(y, y_pred))
print('recall: ', recall_score(y, y_pred))





