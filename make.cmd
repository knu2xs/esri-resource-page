:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: LICENSING                                                                    :
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::
:: Copyright 2020 Esri
::
:: Licensed under the Apache License, Version 2.0 (the "License"); You
:: may not use this file except in compliance with the License. You may
:: obtain a copy of the License at
::
:: http://www.apache.org/licenses/LICENSE-2.0
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
:: implied. See the License for the specific language governing
:: permissions and limitations under the License.
::
:: A copy of the license is available in the repository's
:: LICENSE file.

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: VARIABLES                                                                    :
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

SETLOCAL
SET PROJECT_DIR=%cd%
SET PROJECT_NAME=density-anomalies
SET SUPPORT_LIBRARY = density_anomalies
SET CONDA_DIR="%~dp0env"

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: COMMANDS                                                                     :
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: Jump to command
GOTO %1

:: Make documentation using mkdocs-material!
:docs
    CALL conda run -p %CONDA_DIR% sphinx-build -a -b html docsrc docs
    GOTO end

:: Build the local environment from the environment file
:env
    :: Create new environment from environment file
    CALL conda env create -p %CONDA_DIR% -f environment.yml
    GOTO end

:: Remove the environment
:remove_env
    CALL conda deactivate
    CALL conda env remove -p %CONDA_DIR% -y
	GOTO end

:: Update sitreps
:update
    cd %PROJECT_DIR%
	git add -A
	git commit -m "update sitreps"
	git pull
	git push
    conda run -p ./env mkdocs build --site-dir "%SystemDrive%\inetpub\wwwroot"
    GOTO end

:end
    EXIT /B
