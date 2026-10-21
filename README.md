# AllyMailer Ruby on Rails

[![Ruby on Rails](https://img.shields.io/gem/v/allymailer-rails)](https://rubygems.org/gems/allymailer-rails) [![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Інтеграція [Ruby SDK AllyMailer](https://github.com/allymailer/allymailer-ruby-sdk) (`allymailer-ruby-sdk`) з Ruby on Rails: клієнт API в application config (`config.allymailer`), ендпоінт вебхуків із перевіркою підпису, транспорт Action Mailer, що надсилає листи через `email/send`.

[Довідник API](https://docs.allymailer.com.ua/ua/web-api-ref) · Документація для LLM: [llms.txt](https://docs.allymailer.com.ua/llms.txt)

## Встановлення

```bash
bundle add allymailer-rails
```

Вимоги: Ruby 2.7+, Rails 6.1+.

## Налаштування

Отримайте API-ключ у [панелі керування](https://cp.allymailer.com) і зберігайте його у змінній оточення, а не в коді:

```bash
export ALLYMAILER_API_KEY="your-api-key"
```

За замовчуванням налаштування беруться зі змінних оточення:

```ruby
# .env / environment: ALLYMAILER_API_KEY=YOUR_API_KEY
# or config/application.rb:
config.allymailer.api_key = ENV.fetch('ALLYMAILER_API_KEY')
config.allymailer.host = 'cp.allymailer.com'
config.action_mailer.delivery_method = :allymailer
```

| Параметр | Змінна оточення | За замовчуванням | Опис |
|---|---|---|---|
| `config.allymailer.api_key` | `ALLYMAILER_API_KEY` |  | API-ключ користувача або проєкту (обов'язковий). |
| `config.allymailer.host` | `ALLYMAILER_HOST` | `cp.allymailer.com` | Хост API (датацентр: `cp.allymailer.com`) або повний базовий URL. |
| `config.allymailer.timeout` | `ALLYMAILER_TIMEOUT` | `30` | Таймаут запиту, секунди. |
| `config.allymailer.webhook_key` | `ALLYMAILER_WEBHOOK_KEY` |  | API-ключ, яким підписані вебхуки (ключ користувача/проєкту вебхука), якщо він відрізняється від API-ключа. |
| `config.allymailer.webhook_path` | `ALLYMAILER_WEBHOOK_PATH` | `/allymailer/webhook` | Шлях ендпоінта вебхуків. |

API-ключ можна зберігати і в credentials (`allymailer: { api_key: ... }`). Маршрут вебхуків `allymailer_webhook` — Rack-ендпоінт (без CSRF і сесії); `config.allymailer.webhook_enabled = false` вимикає його.

## Надсилання листів

Листи Action Mailer надсилаються через [email/send](https://docs.allymailer.com.ua/ua/web-api-ref#email-send): відправник, to/cc/bcc, reply-to, тема, HTML і текстова частини, вкладення, inline-зображення та заголовки `X-*`.

```ruby
class OrderMailer < ApplicationMailer
  def shipped(order)
    headers['X-Order-Id'] = order.id.to_s
    attachments['invoice.pdf'] = order.invoice_pdf
    mail(to: order.email, cc: order.manager_email, subject: 'Order shipped')
  end
end

message = OrderMailer.shipped(order).deliver_now
message.delivery_method.response['job_id']
```

Домену ще немає? Надсилайте з [тестового sandbox-домену](#без-свого-домену-тестовий-sandbox-домен).

## Вебхуки

Ендпоінт відповідає 200 OK на `GET` (перевірка URL під час [webhook/set](https://docs.allymailer.com.ua/ua/web-api-ref#webhook-set)) і приймає `POST`-сповіщення: перевіряє поле `auth` (MD5 тіла запиту, у якому значення `auth` замінено на API-ключ), на неправильний підпис відповідає 401, а сповіщення і кожну його подію передає застосунку.

```ruby
# config/initializers/allymailer.rb
ActiveSupport::Notifications.subscribe('event.allymailer') do |*, payload|
  event = payload[:event]
  data = event.event_data
  Rails.logger.info("AllyMailer #{event.event_name}: #{data&.email} #{data&.status}")
end
```

Зареєструйте URL ендпоінта методом `webhook/set`, наприклад `https://example.com/allymailer/webhook`.

> **Відповідайте 200 протягом 3 секунд**, а події обробляйте у фоні (через чергу): інакше AllyMailer повторює запит кожні 10 хвилин протягом доби (зростає `retry_count`), а обробник, на якому за добу не пройшов жоден запит хоча б для 10 подій, вимикається. Обробник має витримувати **щонайменше 5 паралельних запитів до 100 подій у кожному**; повтор надсилає ті самі події ще раз — прибирайте дублікати.

## Клієнт API

Усі розділи API доступні через клієнт, див. [документацію SDK](https://github.com/allymailer/allymailer-ruby-sdk).

```ruby
client = AllyMailer::Wrapper.client
info = client.system.info
puts info.accounting&.emails_sent
```

### Надсилання через API

Окрім Action Mailer, листи можна надсилати напряму через клієнт API. Клієнт викликає [email/send](https://docs.allymailer.com.ua/ua/web-api-ref#email-send) з усіма його параметрами: шаблони, підстановки, метадані, трекінг. Поля запиту та інші приклади — у [документації Ruby SDK](https://github.com/allymailer/allymailer-ruby-sdk/blob/HEAD/docs/Email.md#send_email).

```ruby
class EmailsController < ApplicationController
  Body = AllyMailer::Common::Model::BodyObject
  Email = AllyMailer::Api::Email::Model
  Recipient = AllyMailer::Api::Email::Model::MessageObjectRecipientsItem

  def create
    client = AllyMailer::Wrapper.client
    message = Email::MessageObject.new(
      recipients: [Recipient.from_address('Олексій <alex@example.com>')],
      body: Body.html('<p>Вітаємо, {{to_name}}! Ваше замовлення надіслано.</p>'),
      subject: 'Ваше замовлення',
      from_email: 'shop@example.com',
      from_name: 'Магазин'
    )
    response = client.email.send_email(Email::EmailSendRequest.new(message: message))
    render json: { job_id: response.job_id }
  end
end
```

## Без свого домену: тестовий sandbox-домен

Поки ваш домен не підтверджено, листи можна надсилати із **sandbox-домену** — тестового домену, який є в кожного облікового запису: він уже підтверджений, DKIM і SPF налаштовані. Листи з нього доставляються лише на підтверджені вами адреси (посилання для підтвердження приходить листом і діє 48 годин), до 100 на день. Через 31 день після створення sandbox-домен видаляється, але його можна отримати знову: наступний виклик `domain/get-sandbox-domain` створить новий (з іншою назвою, тому беріть її з відповіді, а не прописуйте в коді).

У прикладах — клієнт API з пакета (див. налаштування вище).

```ruby
class SandboxController < ApplicationController
  Body = AllyMailer::Common::Model::BodyObject
  ConfirmedEmail = AllyMailer::Api::ConfirmedEmail::Model
  Email = AllyMailer::Api::Email::Model
  Recipient = AllyMailer::Api::Email::Model::MessageObjectRecipientsItem

  def create
    client = AllyMailer::Wrapper.client

    # 1. Ваш sandbox-домен: створюється під час першого виклику, далі повертається той самий
    domain = client.domain.get_sandbox_domain.domain

    # 2. Підтвердіть свою скриньку: AllyMailer надішле посилання, перейдіть за ним протягом 48 годин
    client.confirmed_email.create(ConfirmedEmail::ConfirmedEmailRequest.new(email: 'you@example.com'))

    # 3. Надішліть із будь-якої адреси sandbox-домену на підтверджену адресу
    message = Email::MessageObject.new(
      recipients: [Recipient.from_address('you@example.com')],
      body: Body.html('<p>Працює!</p>'),
      subject: 'Привіт від AllyMailer',
      from_email: "noreply@#{domain}"
    )
    client.email.send_email(Email::EmailSendRequest.new(message: message))

    render json: { domain: domain }
  end
end
```

<details>
<summary>Обмеження sandbox</summary>

- Надсилання лише на підтверджені адреси: до 10 на обліковий запис.
- До 100 листів на день.
- Sandbox-домен спливає через 31 день; знову викличте `domain/get-sandbox-domain`, щоб отримати новий.
- Працює лише з API-ключем облікового запису, не з ключем проєкту.
- Не показується в `domain/list`; інші методи `domain/*` до нього не застосовуються.

Sandbox — для розробки та тестування. Не використовуйте sandbox-домен як відправника на проді.

</details>

<details>
<summary>Те саме через curl</summary>

```bash
BASE=https://cp.allymailer.com/ua/transactional/api/v1

curl -s -X POST $BASE/domain/get-sandbox-domain.json \
  -H "Content-Type: application/json" -H "X-API-KEY: $ALLYMAILER_API_KEY" -d '{}'

curl -s -X POST $BASE/confirmed-email/create.json \
  -H "Content-Type: application/json" -H "X-API-KEY: $ALLYMAILER_API_KEY" \
  -d '{"email": "you@example.com"}'

curl -s -X POST $BASE/email/send.json \
  -H "Content-Type: application/json" -H "X-API-KEY: $ALLYMAILER_API_KEY" \
  -d '{
        "message": {
          "recipients": [
            {
              "email": "you@example.com"
            }
          ],
          "from_email": "noreply@<sandbox-domain>",
          "subject": "Привіт від AllyMailer",
          "body": {
            "html": "<p>Працює!</p>"
          }
        }
      }'
```

</details>

## Запуск у продакшен

**1. Підтвердіть домен надсилання.** `domain/get-dns-records` повертає запис підтвердження, DKIM-ключ і адресу для DMARC; додайте записи у свого DNS-провайдера, потім `domain/validate-verification-record` і `domain/validate-dkim`.

| Тип | Хост | Значення | Звідки взяти |
|---|---|---|---|
| TXT | `@` | `allymailer-validate-hash=…` | поле `verification-record` відповіді, як є |
| TXT | `<селектор>._domainkey` (селектор — на сторінці домену в панелі керування, наприклад `us`) | `v=DKIM1; k=rsa; p=<dkim>` | поле `dkim` відповіді після `v=DKIM1; k=rsa; p=` |
| TXT | `@` | `v=spf1 include:spf.allymailer.com ~all` | у відповіді немає; якщо SPF-запис уже є, додайте include до нього |
| CNAME | `_dmarc` | `<домен>.dmarc.…` | поле `dmarc` відповіді (DMARC-політику публікує AllyMailer); якщо в домену вже є свій TXT-запис DMARC, залиште його |

**2. Надійне надсилання.**

| | |
|---|---|
| Повтори | `429` і `5xx` з backoff і тим самим `idempotence_key`; інші помилки виправляйте, а не повторюйте |
| Ліміти | 500 одержувачів і 10 МБ на запит разом із вкладеннями: у base64 файл стає приблизно на третину більшим |
| Тіло | завжди `html` або `plaintext` (або із шаблону) |
| Статус доставки | вебхук, а не опитування |
| Черга | надсилайте з фонового завдання, а не всередині веб-запиту |
| Налаштування | `from_email` з конфігурації: перехід із sandbox на продакшен без змін у коді |
| Типові налаштування | не прибирайте блок відписки та трекінг; змінити їх можна через підтримку AllyMailer |

## Допомога

- [Ruby SDK](https://github.com/allymailer/allymailer-ruby-sdk)
- Для ШІ-агентів: [llms.txt](https://docs.allymailer.com.ua/llms.txt), скіли: `npx skills add https://github.com/allymailer/allymailer-skills.git`
- [Підтримка](https://cp.allymailer.com/ua/support) · [Задачі](https://github.com/allymailer/allymailer-rails/issues)
- Розробникам: [AGENTS.md](AGENTS.md) — пакет генерується з OpenAPI-специфікації.
