# Perturbome modeling with Tidymodels

Here I attempt to reproduce results from [A first perturbome of
_Pseudomonas aeruginosa_: Identification of core genes related to 
multiple perturbations by a machine learning 
approach](https://www.sciencedirect.com/science/article/pii/S0303264721000666?casa_token=5gk_UgzOCsUAAAAA:2ZMo4UByW6bLZpLNtN42cuE8a_KZyWsyGjnW5mqQh7SFM8vQCZIVBlJekwqbcqBsoozuzebawwLw), using  the Tidymodels 
framework instead of caret.

Original code of the paper can be found here: [Molina-Mora et al., 2021](https://github.com/josemolina6/Perturbome)

For this paper, three models were built for identification of top 
genes: a Random Forest, a Support Vector Machine and a K-nearest 
neighbor.

### Random Forest model
_Key difference_ : Here feature importance was calculated using the [vip](https://koalaverse.github.io/vip/articles/vip.html) package rather than caret::varImp . This package uses model-specific importances for tree-based models such as RF and xgboost.

<img src="model_plots.png" alt = "sp_rf_results"/>

### Support Vector Machine model

accuracy: 0.773
roc_auc: 0.906
SVM seems more likely to predict "Perturbation".

<img src="svm_model_plots.png" alt = "sp_svm_results"/>


Obtaining feature importance for the SVM and KNN models, vip 
permutation-based importance seems to take a long time as this 
particular dataset contains more than 5000 features. 


### K-nearest neighbor model

accuracy: 0.773
roc_auc: 0.739

<img src="kknn_model_plots.png" alt = "kknn_svm_results"/>

