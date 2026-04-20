# Question 4 — ClinicalTrialDataAgent (Python + LangChain + OpenAI)

Bonus question. A natural language agent that lets a clinical safety reviewer
ask free-text questions about an ADAE dataset without knowing the column names.
The LLM routes the question to the right CDISC column (AESEV, AETERM, or
AESOC); pandas runs the actual filter.

## Pipeline

```
Question  ->  LangChain + OpenAI (gpt-4o-mini)  ->  JSON { target_column, filter_value }  ->  pandas filter  ->  unique subjects
```

The LLM never sees the dataframe — it only sees the question and the column
descriptions in the system prompt. pandas handles the filter.

## Files

| File | Purpose |
|---|---|
| `llm_openai_langchain.py` | Agent class + interactive CLI |
| `adae.csv` | ADAE dataset (exported from `pharmaverseadam::adae`) |
| `requirements.txt` | Python dependencies |
| `.env.example` | Template for the OpenAI API key |

## Setup

```bash
# from inside question_4_python_llm/
python -m venv .venv
.venv\Scripts\activate        # Windows
source .venv/bin/activate     # macOS/Linux

pip install -r requirements.txt

# copy the template and add your key
copy .env.example .env        # Windows
cp .env.example .env          # macOS/Linux
# then edit .env and paste your OPENAI_API_KEY

python llm_openai_langchain.py
```

## How to use

On start, the script loads ADAE and drops into an interactive prompt. Type a
question, press Enter. Type `quit` to exit.

### Example questions to try

| Question | Expected |
|---|---|
| *Give me the subjects who had adverse events of moderate severity.* | 136 subjects |
| *Which patients had cardiac events?* | 44 subjects |
| *Show me everyone who had headaches.* | 16 subjects |
| *Which patients had pruritus?* | 57 subjects |
| *Who experienced dizziness?* | 22 subjects |

## Known limitation

The LLM occasionally picks the wrong column or invents CDISC values that don't
exist in the data, which returns 0 subjects.
