# Extract and identify first appearances of the scholarly bibliographic references on Wikipedia articles

## Abstract
Referencing scholarly documents as information sources on Wikipedia is important because it supports or improves the quality of Wikipedia content. Several studies have been conducted regarding scholarly references on Wikipedia; however, little is known of the editors and their edits contributing to add the scholarly references on Wikipedia. In this study, we develop a methodology to detect the oldest scholarly reference added to Wikipedia articles by which a certain paper is uniquely identifiable as the "first appearance of the scholarly reference." We identified the first appearances of 923,894 scholarly references (611,119 unique DOIs) in 180,795 unique pages on English Wikipedia as of March 1, 2017 and stored them in the dataset. Moreover, we assessed the precision of the dataset, which was highly precise regardless of the research field. Finally, we demonstrate the potential of our dataset. This dataset is unique and attracts those who are interested in how the scholarly references on Wikipedia grew and which editors added them.

## Requirements
- This program is written in Ruby, so it requires a Ruby environment and the gems such as 'levenshtein', 'nokogiri', 'sanitize', and 'htmlentities.'
- Installing ParsCit (https://github.com/knmnyn/ParsCit) is required to run this program.
  - It is needed to be changed "@path_parscit" value in extract_by_paper_title_similarity_step1.rb depending on your environment.

## Usage
Due to file size limitations, sample data of the revisions of the pages "Fair trade" and "Solomon Islands" and identifiers referenced on them are available on this repository. To generate the full dataset, some preprocessing is needed. Please refer to the data descriptor above for the details of them.

- Just run main.sh ($ sh main.sh)
  - Finally, the files "./result/*_final.jsonl.gz" are generated.
- The data in this repository covers for the 2 pages on English Wikipedia, "Fair trade" and "Solomon Islands" due to file size limitations.

## References
### Dataset
- Kikkawa, J., Takaku, M. & Yoshikane, F. "Dataset of first appearances of the scholarly bibliographic references on English Wikipedia articles as of 1 March 2017 and as of 1 October 2021". *Zenodo* https://doi.org/10.5281/zenodo.5595573 (2021).
### Paper
- Kikkawa, J., Takaku, M. & Yoshikane, F. "Dataset of first appearances of the scholarly bibliographic references on Wikipedia articles", *Scientific Data*, Vol. 9, No. 1, pp. 1-11, 2022. https://doi.org/10.1038/s41597-022-01190-z.


## Contact

Please contact me if you have any questions.

Jiro Kikkawa, Ph.D. <br>
Assistant Professor <br>
Faculty of Library, Information and Media Science <br>
University of Tsukuba <br>
1-2 Kasuga, Tsukuba, 305-8550, Ibaraki, Japan <br>
Email Address: jiro [at] slis.tsukuba.ac.jp
