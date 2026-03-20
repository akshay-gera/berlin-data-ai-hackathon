# Lightdash

[Lightdash](https://www.lightdash.com/) is an open-source BI tool connected to your team's Snowflake database. Use it to build dashboards and visualisations for your analysis and final presentation.

There are two ways to use Lightdash:

1. **SQL Runner** — Write SQL directly, visualise results, build dashboards. No setup required.
2. **Explore** — Browse dbt models as interactive dimensions and metrics. Requires deploying a dbt project.

## GUI Access

- **URL**: [hackathon.lightdash.cloud](https://hackathon.lightdash.cloud)
- **Login**: you'll receive an email invite — click the link and create your account
- **Project**: your team project (Team 1, Team 2, etc.) is pre-selected based on your group

### Quick start with SQL Runner

1. Accept the email invite and create your Lightdash account
2. Your team project is already set up — select it from the project switcher (top-left)
3. Open the **SQL Runner** to write queries and visualise results
4. Build dashboards combining multiple charts
5. Share dashboards with your team and the judges

The SQL Runner can query both the shared data (`DB_JW_SHARED.CHALLENGE.*`) and your team's database (`DB_TEAM_<N>`).

## Setting Up dbt + Lightdash Explore

> **Important:** Each team's Lightdash project is connected to your team's private database (`DB_TEAM_<N>`), **not** the shared database. This means you need to:
> 1. Set up a dbt project that materializes models into `DB_TEAM_<N>`
> 2. Deploy those models to Lightdash so they appear under **Explore**
>
> Your dbt models will read from the shared data (`DB_JW_SHARED.CHALLENGE`) but write to your team database — that's where Lightdash looks.

### Step 1: Copy the dbt template

The repo includes a starter dbt project in `dbt_template/`. Copy it to your working directory:

```bash
cp -r dbt_template/ my-dbt-project
cd my-dbt-project
```

The template comes with:

- Source definitions for all shared tables (T1–T4, OBJECTS, PACKAGES)
- Base models (simple pass-through views) for each table
- Empty directories for your own analyses, tests, macros, and seeds

### Step 2: Create your dbt profile

dbt needs a `profiles.yml` to connect to Snowflake. Create one at `~/.dbt/profiles.yml`:

```yaml
dbt_template:
  outputs:
    dev:
      type: snowflake
      account: "<ACCOUNT_ID>"
      user: "<your-email>"
      password: "<your-password>"
      database: DB_TEAM_<N>          # ← your team's private database (e.g. DB_TEAM_1)
      schema: base
      warehouse: WH_TEAM_<N>_XS     # ← your team's warehouse (e.g. WH_TEAM_1_XS)
      threads: 4
  target: dev
```

Replace `<ACCOUNT_ID>`, your credentials, and `<N>` with your team number. The `database` must be your team database — this is where dbt will create views and tables that Lightdash can read.

Install dbt if you haven't already:

```bash
pip install dbt-snowflake
```

### Step 3: Run dbt

```bash
cd my-dbt-project

# Verify your connection
dbt debug

# Build the base models (creates views in DB_TEAM_<N>.base)
dbt run
```

After `dbt run`, you should see views like `DB_TEAM_<N>.base.base_events_t1`, `DB_TEAM_<N>.base.base_objects`, etc. in Snowflake. These read from the shared data but live in your team database.

### Step 4: Install and authenticate the Lightdash CLI

```bash
# Install
npm install -g @lightdash/cli

# Verify
lightdash --version

# Authenticate
lightdash login https://hackathon.lightdash.cloud --token <YOUR_PERSONAL_ACCESS_TOKEN>
```

To get your personal access token:

1. Log in to [hackathon.lightdash.cloud](https://hackathon.lightdash.cloud)
2. Click your avatar (bottom-left) → **Settings**
3. Go to **Personal Access Tokens** → **Create new token**
4. Copy the token and use it in the command above

### Step 5: Set your team project

```bash
# List available projects to find your team's project UUID
lightdash config list-projects

# Set your team's project as default
lightdash config set-project --project <PROJECT_UUID>
```

### Step 6: Deploy to Lightdash

From your dbt project directory:

```bash
cd my-dbt-project

# Compile dbt and deploy models to Lightdash
lightdash deploy
```

After deploying, your dbt models appear under **Explore** in the Lightdash UI. You can build charts using model dimensions and metrics without writing SQL.

### Adding your own models

Once the base setup works, add your analysis models on top. For example:

```text
models/
  base/           ← starter models (already provided)
  marts/          ← your analysis models (create this)
    top_titles.sql
    provider_market_share.sql
    ...
```

After adding or changing models, re-run and re-deploy:

```bash
dbt run
lightdash deploy
```

## End-to-end flow summary

```text
┌─────────────────────────────────────────────────────────────────┐
│  DB_JW_SHARED.CHALLENGE     DB_TEAM_<N>        Lightdash       │
│  (shared, read-only)        (your team DB)     (your project)  │
│                                                                 │
│  T1, T2, T3, T4  ──dbt──▶  base.base_events   ──deploy──▶     │
│  OBJECTS          ──dbt──▶  base.base_objects      Explore      │
│  PACKAGES         ──dbt──▶  base.base_packages     (charts &   │
│                             marts.your_model        dashboards) │
│                                                                 │
│  All tables       ─────────────────────────────▶  SQL Runner    │
│                             (direct SQL, no dbt needed)         │
└─────────────────────────────────────────────────────────────────┘
```

## Vendor resources

- [Lightdash Resources for Hackathon Attendees](resources/lightdash_resources.pdf)
- [Lightdash documentation](https://docs.lightdash.com/)
- [SQL Runner guide](https://docs.lightdash.com/guides/sql-runner/)

Oli from Lightdash will give a live demo during the kickoff.
