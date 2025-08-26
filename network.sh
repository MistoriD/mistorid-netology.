#!/bin/bash

# Проверка на root
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: Запускайте скрипт с sudo."
    exit 1
fi

# Проверка: минимум 2 аргумента
if [[ $# -lt 2 ]]; then
    echo "Использование: $0 <PREFIX> <INTERFACE> [SUBNET] [HOST]"
    exit 1
fi

# Аргументы
PREFIX="$1"
INTERFACE="$2"
SUBNET="$3"
HOST="$4"

# Проверка интерфейса
if ! ip link show "$INTERFACE" &>/dev/null; then
    echo "Ошибка: интерфейс '$INTERFACE' не существует."
    exit 1
fi

# Проверка формата PREFIX: два числа от 0 до 255, разделённые точкой
if ! [[ "$PREFIX" =~ ^([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    echo "Ошибка: PREFIX должен быть в формате 'xxx.xxx'"
    exit 1
fi

# Функция сканирования одного IP
scan() {
    local ip="$1"
    echo "Пингую: $ip"
    arping -c 3 -i "$INTERFACE" "$ip" &>/dev/null && echo "    Активен: $ip"
}

# === Логика запуска ===

if [[ -z "$SUBNET" ]]; then
    # Режим 1: сканируем всё — все подсети и хосты
    echo "Полное сканирование: $PREFIX.*.*"
    for s in {1..254}; do
        for h in {1..254}; do
            scan "$PREFIX.$s.$h"
        done
    done

elif [[ -z "$HOST" ]]; then
    # Режим 2: только подсеть
    if ! [[ "$SUBNET" =~ ^[0-9]+$ ]] || (( SUBNET < 0 || SUBNET > 255 )); then
        echo "Ошибка: SUBNET должен быть числом от 0 до 255"
        exit 1
    fi
    echo "Сканирование подсети: $PREFIX.$SUBNET.*"
    for h in {1..254}; do
        scan "$PREFIX.$SUBNET.$h"
    done

else
    # Режим 3: один IP
    if ! [[ "$HOST" =~ ^[0-9]+$ ]] || (( HOST < 0 || HOST > 255 )); then
        echo "Ошибка: HOST должен быть числом от 0 до 255"
        exit 1
    fi
    echo "Сканирование одного IP: $PREFIX.$SUBNET.$HOST"
    scan "$PREFIX.$SUBNET.$HOST"
fi

echo "Готово."