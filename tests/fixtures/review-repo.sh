#!/usr/bin/env bash
# Scratch Kotlin repo on feature/TA-1234 with an approved ticket and an uncommitted change.
# Usage: review-repo.sh <defects|clean> [passed]
#   defects: the ViewModel calls the Api directly, uses !! on the body, and is not wired.
#   clean:   the ViewModel goes through the use case, maps failure to a state, and is wired.
#   passed:  also record review and security passes for the current changes.
set -eu
shape="${1:?defects or clean}"; passed="${2:-}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# The fingerprint command, taken from its contract so the fixture can never drift from it.
fp_cmd="$(awk '/^## The diff fingerprint/{s=1} s&&/^```bash/{c=1;next} c&&/^```/{exit} c' \
  "$root/shared/ticket-file.md" | sed 's/<base_branch>/develop/g')"
dir="$(mktemp -d)"; cd "$dir"
git init -q -b develop .
git config user.email t@example.com; git config user.name Test
pkg=app/src/main/java/com/example/cancel; di=app/src/main/java/com/example/di
mkdir -p "$pkg" "$di" .ai/project
cat > .ai/project/android-workflow.yml <<'YML'
workflow_version: 0.2.0
app_tag: TEST
base_branch: develop
build:
  gradle_file: app/build.gradle
  lint_task: lintDebug
  test_task: testDebugUnitTest
release_notes:
  file: release_notes.txt
YML
cat > .ai/project/architecture.md <<'MD'
# Architecture
- Layering: `ViewModel → UseCase → Repository → Api`. A ViewModel never calls an `*Api` interface.
- Repositories return `Result<T>`; ViewModels map a failure to an error state the UI can show.
- Wiring: every ViewModel gets a factory function in `app/src/main/java/com/example/di/AppModule.kt`.
MD
printf '# Conventions\n- User-facing strings live in `res/values/strings.xml`.\n' > .ai/project/conventions.md
printf 'android {\n  defaultConfig {\n    versionCode 60\n    versionName "3.4.27"\n  }\n}\n' > app/build.gradle
: > release_notes.txt
cat > "$pkg/CancelApi.kt" <<'KT'
package com.example.cancel

import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST

data class CancelRequest(val reasonCode: String)
data class CancelResponse(val status: String)

interface CancelApi {
    @POST("subscriptions/cancel")
    suspend fun cancel(@Body body: CancelRequest): Response<CancelResponse>
}
KT
cat > "$pkg/CancelRepository.kt" <<'KT'
package com.example.cancel

class CancelRepository(private val api: CancelApi) {
    suspend fun cancel(reasonCode: String): Result<CancelResponse> = runCatching {
        api.cancel(CancelRequest(reasonCode)).body() ?: error("empty body")
    }
}
KT
cat > "$pkg/CancelUseCase.kt" <<'KT'
package com.example.cancel

class CancelUseCase(private val repository: CancelRepository) {
    suspend operator fun invoke(reasonCode: String) = repository.cancel(reasonCode)
}
KT
cat > "$di/AppModule.kt" <<'KT'
package com.example.di

object AppModule
KT
git add -A && git commit -qm "initial"
git checkout -qb feature/TA-1234

if [ "$shape" = "defects" ]; then
cat > "$pkg/CancelReasonViewModel.kt" <<'KT'
package com.example.cancel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class CancelReasonViewModel(private val api: CancelApi) : ViewModel() {
    private val _status = MutableStateFlow("")
    val status: StateFlow<String> = _status

    fun submit(reasonCode: String) {
        viewModelScope.launch {
            val response = api.cancel(CancelRequest(reasonCode))
            _status.value = response.body()!!.status
        }
    }
}
KT
else
cat > "$pkg/CancelReasonViewModel.kt" <<'KT'
package com.example.cancel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class CancelReasonViewModel(private val cancel: CancelUseCase) : ViewModel() {
    private val _state = MutableStateFlow<CancelState>(CancelState.Idle)
    val state: StateFlow<CancelState> = _state

    fun submit(reasonCode: String) {
        viewModelScope.launch {
            _state.value = cancel(reasonCode).fold(
                onSuccess = { CancelState.Done(it.status) },
                onFailure = { CancelState.Error },
            )
        }
    }
}

sealed interface CancelState {
    data object Idle : CancelState
    data class Done(val status: String) : CancelState
    data object Error : CancelState
}
KT
cat > "$di/AppModule.kt" <<'KT'
package com.example.di

import com.example.cancel.CancelApi
import com.example.cancel.CancelReasonViewModel
import com.example.cancel.CancelRepository
import com.example.cancel.CancelUseCase

object AppModule {
    fun cancelReasonViewModel(api: CancelApi) =
        CancelReasonViewModel(CancelUseCase(CancelRepository(api)))
}
KT
fi

fp="$(bash -c "$fp_cmd")"
tdir="$(git rev-parse --git-common-dir)/android-workflow"; mkdir -p "$tdir"
{
  printf -- '---\nkey: TA-1234\nname: Cancel reason\ntype: feature\nbranch: feature/TA-1234\n'
  printf 'architecture: MVVM\nplan_approved: 2026-09-22T10:00+08:00\n'
  printf 'related:\n  result: waived\n  checked: 2026-09-22T09:50+08:00\n  tickets:\n'
  printf '    - {key: TA-2001, role: BE, status: QA TESTING, found: link}\n'
  printf '    - {key: TA-2002, role: UI, status: DEVELOPMENT, found: sibling}\n'
  printf '  waivers:\n    - {ticket: TA-2002, reason: "Design signed off in the review call; ticket not moved yet"}\n'
  if [ "$passed" = "passed" ]; then
    printf 'review:\n  result: pass\n  diff: %s\nsecurity:\n  result: pass\n  diff: %s\n' "$fp" "$fp"
  fi
  printf 'workflow_version: 0.2.0\n---\n\n## Acceptance criteria\n\n'
  printf -- '- Submitting a reason cancels the subscription and shows the returned status.\n'
  printf -- '- A failed cancel shows an error state.\n\n## From BE tickets\n\n'
  printf 'TA-2001: `POST subscriptions/cancel`, body `{reasonCode: String}`, returns `{status: String}`; 4xx on an unknown code. Callable on QA.\n\n'
  printf '## From UI tickets\n\nTA-2002: not yet designed (waived).\n\n## Approved plan\n\n'
  printf 'Add `CancelReasonViewModel` using `CancelUseCase`, exposing idle, done and error states; add its factory to `AppModule`.\n'
} > "$tdir/TA-1234.md"
printf '%s\n' "$dir"
