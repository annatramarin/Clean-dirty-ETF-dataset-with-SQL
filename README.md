# Overview

This repository contains the code and data of a SQL data cleaning project. 
The starting database is a dirty Claude-generated dataset about ETFs (Exchange Traded Funds)


### Process

A dirty dataset about ETFs was generated using Claude.

The resulting CSV file was then imported into MySQL and cleaned from empty values, inconsistencies and duplicates.


Let us first have a look at our data.

```
Select *
from dirty_etf_dataset
limit 10;
```

