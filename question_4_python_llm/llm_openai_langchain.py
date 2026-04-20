"""
ClinicalTrialDataAgent - Roche ADS Q4 coding assessment.

Routes natural-language AE questions to the right CDISC column
(AESEV/AETERM/AESOC) using an LLM, then runs a pandas filter.

--- Example questions in command line ---
Give me the subjects who had adverse events of moderate severity.
Which patients had cardiac events?
Show me everyone who had headaches.
Which patients had pruritus?
Subjects who experienced vomiting?

# Known limitation:
LLM hallucinates and sometimes picks the wrong column or makes up category names
that don't exist in the data, which returns 0 subjects when asking a vague question.
"""

import os
from typing import Literal

import pandas as pd
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
from pydantic import BaseModel, Field

load_dotenv()


def load_adae(path: str = "adae.csv") -> pd.DataFrame:
    """Load the ADAE dataset from CSV."""
    return pd.read_csv(path, low_memory=False)


def filter_adae(adae: pd.DataFrame, target_column: str, filter_value: str) -> dict:
    """Filter ADAE on a column and return unique subjects."""
    matched = adae[adae[target_column].str.upper() == filter_value.upper()]
    subject_ids = sorted(matched["USUBJID"].unique().tolist())

    return {
        "target_column": target_column,
        "filter_value": filter_value.upper(),
        "subject_count": len(subject_ids),
        "subject_ids": subject_ids,
    }


class ADAEQuery(BaseModel):
    """Pydantic schema for the LLM's structured output."""

    target_column: Literal["AESEV", "AETERM", "AESOC"] = Field(
        description=(
            "Which ADAE column the question is about. "
            "AESEV = severity (MILD/MODERATE/SEVERE). "
            "AETERM = specific condition (e.g. HEADACHE, PRURITUS). "
            "AESOC = body system (e.g. CARDIAC DISORDERS)."
        )
    )
    filter_value: str = Field(
        description="The value to filter for, extracted from the question."
    )


class ClinicalTrialDataAgent:
    """LLM-backed agent for natural-language queries against ADAE."""

    def __init__(self, adae: pd.DataFrame, model: str = "gpt-4o-mini"):
        self.adae = adae
        self.llm = ChatOpenAI(model=model, temperature=0).with_structured_output(ADAEQuery)

    def parse(self, question: str) -> dict:
        """Translate a natural language question into a filter dict via the LLM."""
        system_prompt = """You are a clinical data assistant. Translate questions about an adverse events (AE) dataset into structured filter instructions.

        The dataset has three relevant columns:
        - AESEV: severity (MILD, MODERATE, SEVERE)
        - AETERM: reported condition (e.g. HEADACHE, PRURITUS, DIZZINESS)
        - AESOC: body system (e.g. CARDIAC DISORDERS, NERVOUS SYSTEM DISORDERS)

        Route to the correct column and extract the value in UPPERCASE."""

        result = self.llm.invoke([
            ("system", system_prompt),
            ("human", question),
        ])
        return result.model_dump()

    def query(self, question: str) -> dict:
        """Full pipeline: question -> LLM -> filter -> subjects."""
        parsed = self.parse(question)
        result = filter_adae(self.adae, **parsed)
        result["question"] = question
        return result


def print_result(result: dict) -> None:
    """Print a query result in a consistent format."""
    print(f"   Routed to: {result['target_column']} = '{result['filter_value']}'")
    print(f"   Subjects: {result['subject_count']}")
    print(f"   First 3 IDs: {result['subject_ids'][:3]}\n")


if __name__ == "__main__":
    adae = load_adae()
    print(f"Loaded ADAE: {adae.shape[0]} rows, {adae.shape[1]} columns\n")

    agent = ClinicalTrialDataAgent(adae)

    print("Ask a question about the ADAE dataset (or type 'quit' to exit).\n")

    while True:
        question = input("Q: ").strip()
        if question.lower() in {"quit", "exit", ""}:
            print("Goodbye.")
            break
        try:
            print_result(agent.query(question))
        except Exception as e:
            print(f"   Error: {e}\n")