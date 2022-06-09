# Copyright 2019 Cargill Incorporated
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM hyperledger/grid-dev:v11 as gridd-builder

ENV GRID_FORCE_PANDOC=true

# This is temporary until hyperledger/grid-dev updates
RUN apt-get update && apt-get install -y -q --no-install-recommends pandoc

# Ran into an issue compiling the cli without this
RUN apt-get install -y -q libc6-dev

RUN mkdir /xgridbuild

CMD ["bash"]
