#!/usr/bin/python3

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
from sklearn.metrics import f1_score, precision_score, recall_score, accuracy_score

data = load_svmlight_file('dataset.svmlight')
x = data[0].todense()
y = data[1]

model = Pipeline([
('column_selector', ColumnSelector(cols=(0,1,2,3,5,6))),
('scaler', StandardScaler()),
('poly', PolynomialFeatures(degree=4)),
#('classifier', LogisticRegression(penalty='l2', solver='liblinear'))
#('classifier', GradientBoostingClassifier())
#('classifier', SVC())
#('classifier', GaussianNB())
#('classifier', KNeighborsClassifier(n_neighbors=13))
('classifier', XGBClassifier())
])

model.fit(x, y)
dump(model, 'classifier.joblib')

y_pred = model.predict(x)
print('accuracy: ', accuracy_score(y, y_pred))
print('f1: ', f1_score(y, y_pred))
print('precision: ', precision_score(y, y_pred))
print('recall: ', recall_score(y, y_pred))




